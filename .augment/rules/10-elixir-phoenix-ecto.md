---
type: "manual"
---

# Elixir • Phoenix • Ecto Rules (Auto)

## Style
- Prefer **pattern matching** & **multi-clause** functions; make functions small and focused.
- Use `with` for sequential checks and include an `else` with explicit error branches.
- Prefer `case` over `if/cond` when matching on data shapes.
- Use pipelines for readable transformations: `params |> validate() |> process()`.
- **Do not** use `try/rescue` in domain code.

## Ecto & Contexts
- **All DB queries live in Context modules**; none in controllers/web.
- Expose tuple APIs: return `{:ok, value}` / `{:error, reason}`; call sites pattern-match.
- Schemas declare and use attributes:
  - `@required_fields [...]`
  - `@optional_fields [...]`
  Use them in `cast/3` + `validate_required/2`.
- Prefer explicit `changeset/2` for inserts/updates (avoid plain `change/2` for business updates).

### Schema pattern
```elixir
schema "users" do
  field :email, :string
  field :name, :string
  timestamps()
end

@required_fields ~w[email]a
@optional_fields ~w[name]a

def changeset(user, attrs) do
  user
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
end
