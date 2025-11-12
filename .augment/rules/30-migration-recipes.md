---
type: "manual"
---

# Migration Recipes (Safe Ecto/Postgres & MySQL)

**Type:** auto
**Description:** Practical, zero-/low-downtime database migration patterns for Ecto (Postgres & MySQL/MariaDB). Summarizes Fly.io’s Phoenix Files “Migration Recipes”.
**Source:** https://fly.io/phoenix-files/migration-recipes/

---

## Always do this first
- Prefer **multi-step** and **multi-deploy** changes over one-shot rewrites.
- Keep each migration focused; **don’t mix** schema changes with long-running ops in the same migration.
- When using `CREATE INDEX CONCURRENTLY` in Postgres, set:
  ```elixir
  @disable_ddl_transaction true
  @disable_migration_lock true
  ```
  and **only** create the index in that migration.

---

## Recipes

### 1) Adding an index (without blocking)
**Bad ❌**
```elixir
def change do
  create index("posts", [:slug])  # blocks writes on Postgres
end
```

**Good ✅ (Postgres)**
```elixir
@disable_ddl_transaction true
@disable_migration_lock true
def change do
  create index("posts", [:slug], concurrently: true)
end
```
> Don’t bundle any other change with a concurrent index migration.

---

### 2) Adding a reference / foreign key (validate in two steps)
**Bad ❌**
```elixir
def change do
  alter table("posts") do
    add :group_id, references("groups")
  end
end
```

**Good ✅**
```elixir
# Migration A
def change do
  alter table("posts") do
    add :group_id, references("groups", validate: false)
  end
end

# Migration B
def change do
  execute "ALTER TABLE posts VALIDATE CONSTRAINT group_id_fkey", ""
end
```

---

### 3) Adding a column with a default (avoid table rewrite)
**Bad ❌** (may rewrite table)
```elixir
def change do
  alter table("comments") do
    add :approved, :boolean, default: false
  end
end
```

**Good ✅** (two migrations)
```elixir
# A: add nullable column
def change do
  alter table("comments") do
    add :approved, :boolean
  end
end

# B: set default
def change do
  alter table("comments") do
    modify :approved, :boolean, default: false
  end
end
```
> Newer DB versions optimized some default additions, but the two-step pattern is broadly safe.

---

### 4) Changing the type of a column (multi-deploy)
**Safe direct changes (Postgres):** increase `varchar` length/remove limit; `varchar`↔`text` (no limit); increase numeric/decimal **precision** (not scale); `timestamp → timestamptz` (with UTC session on PG12+).
**Else do this:**

**Good ✅ (multi-deploy)**
1. Add new column (target type, nullable)
2. App writes to **both** columns
3. Backfill old → new
4. App reads from **new** column
5. Remove old field from schemas
6. Drop old column

---

### 5) Removing a column (multi-stage)
**Bad ❌** remove while old code still expects it.
**Good ✅**
- Deploy app that **stops using** the column (remove from schema/queries).
- Then run migration to **remove** the column.

---

### 6) Renaming a column (prefer schema aliasing)
**Shortcut ✅ (no DB rename):**
```elixir
schema "weather" do
  field :precipitation, :float, source: :prcp
end
```
Update calling code to the new field name.

**If you must rename at DB level:** treat like a type change → new column, dual-write, backfill, flip reads, drop old.

---

### 7) Renaming a table (prefer schema rename)
**Shortcut ✅:** rename the **Ecto schema module/name**, keep table name unchanged.

**If you must rename DB table:** create new table, dual-write, backfill, flip reads, drop old table (multi-stage).

---

### 8) Adding a check constraint (validate later)
**Bad ❌**
```elixir
create constraint("products", :price_must_be_positive, check: "price > 0")
```

**Good ✅**
```elixir
# A: add without validation
def change do
  create constraint("products", :price_must_be_positive, check: "price > 0"), validate: false
end

# B: validate later
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive", ""
end
```

---

### 9) Setting NOT NULL on an existing column (constraint-first)
**Bad ❌**
```elixir
alter table("products") do
  modify :active, :boolean, null: false
end
```

**Good ✅**
```elixir
# A: add nonvalidating check
create constraint("products", :active_not_null, check: "active IS NOT NULL"), validate: false

# (optional) backfill data to satisfy the constraint

# B: validate then convert to NOT NULL (PG12+) & drop check
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT active_not_null", ""

  alter table("products") do
    modify :active, :boolean, null: false
  end

  drop constraint("products", :active_not_null)
end
```

---

### 10) Adding a JSON column (prefer `jsonb`)
**Bad ❌**
```elixir
add :extra_data, :json
```
**Good ✅**
```elixir
add :extra_data, :jsonb
```

---

## Quick checklist
- [ ] Separate long-running ops (indexes, validations) into their **own** migrations
- [ ] Use **concurrent** indexes with `@disable_ddl_transaction` & `@disable_migration_lock` (Postgres)
- [ ] Favor **two-step** defaults and **constraint-then-validate** patterns
- [ ] Use **multi-deploy** for breaking schema changes (type/rename/remove)
- [ ] Prefer **`jsonb`** over `json` in Postgres
