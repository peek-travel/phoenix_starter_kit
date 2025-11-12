---
type: "always_apply"
---

# User Guidelines (Global)

These apply to all chats and agents across my projects.

- Work in **small, reviewable steps**; don’t “run ahead.” If a task implies broad refactors, propose a plan first.
- **Never** use `try/rescue` in Elixir application code. Prefer failing fast and handle errors only at **boundaries** (controllers/plugs, jobs, CLI).
- **Testing:** Aim for complete and **meaningful** coverage. Remove tests that don’t add value or coverage. Prefer doctests for utilities; use `on_exit` for cleanup.
- Prefer **pattern matching** and **multi-clause** functions over `if/else`. Prefer `with` (with explicit `else`) for sequential checks; prefer `case` over `if/cond` when matching shapes.
- **Queries live in Contexts** (Ecto) — never in the web layer. Keep functions simple; favor pipelines.
- When a suggestion conflicts with these rules, **follow the rules** and briefly explain the conflict.
- **Architecture docs:** Keep `docs/architecture.md` accurate. If a PR changes module boundaries, data model, or public APIs, update it in the same PR or state “no architecture impact”.

## VERY IMPORTANT — Fail Fast (No Defensive Code)
- Avoid defensive code or nested case statements...
...
# Prefer (fail fast via pattern matching)
def parse_user(%{"id" => id}), do: do_something(id)
