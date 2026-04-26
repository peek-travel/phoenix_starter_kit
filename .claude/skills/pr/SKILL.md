---
name: pr
description: Creates a pull request following the team's conventions: conventional-commit-style title with Jira ticket number, and a body that fills out the PULL_REQUEST_TEMPLATE.md (Jira ticket links, What section, Risk Assessment). Use when the user invokes /pr or asks to open, create, or draft a pull request.
---

# /pr — Create a Pull Request

## Workflow

### Step 1 — Gather required info

**Ticket number(s)**: Extract all matches of `[A-Z]+-\d+` from the branch name (e.g. `APP-1234`). There may be zero, one, or many. If the branch name is ambiguous and a ticket seems likely, use `AskUserQuestion` to ask.

**Base branch**: Always use `AskUserQuestion` to confirm the base.

If both ticket and base branch are ambiguous, ask both in a single `AskUserQuestion` call (max 2 questions).

### Step 2 — Read the diff

```bash
git diff <base>...HEAD
git log <base>...HEAD --oneline
```

### Step 3 — Draft the PR title

e.g.
```
APP-1234, APP-5678 type(scope): short imperative description
```

- `type`: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `ci`, `build`
- `scope`: affected module in lowercase (e.g. `templates`, `auth`, `orders`)
- Total length under 72 chars

### Step 4 — Fill the PR body

Read `.github/pull_request_template.md` and use it as the PR body structure.

**Tickets section**: 
- If one or more tickets were found, render each as a linked list item using `https://peeksters.atlassian.net/browse/<ticket>`:
  ```
  ## Tickets
  - [APP-1234](https://peeksters.atlassian.net/browse/APP-1234)
  ```
- If no tickets were found, **remove the entire `## Tickets` section** from the body.

Fill in the `What` bullets with a concise description of the changes.

For the Risk Assessment, pick exactly one based on the diff and change its `[ ]` to `[x]`. Leave all others unchecked:

| Level | When to use                                              |
| ----- | -------------------------------------------------------- |
| RA 0  | Tests, docs, CI, chores only — zero runtime impact       |
| RA 1  | Small change, non-critical path, excellent test coverage |
| RA 2  | Check it does what it says; no deep regression needed    |
| RA 3  | Normal feature; find the edge cases                      |
| RA 4  | Sensitive area (auth, payments, permissions, migrations) |
| RA 5  | High blast radius or unknown territory                   |

### Step 5 — Push and create

If the branch has no upstream:

```bash
git push -u origin <branch>
```

Create the PR:

```bash
gh pr create --base <base-branch> --title "<title>" --body "<body>"
```

### Step 6 — Return the PR URL

## Rules

- Never use `--force` or `--no-verify`.
- Do not fabricate ticket numbers — always use `AskUserQuestion` if uncertain.
- If `gh` is not authenticated, surface the error immediately.
- Never include `Co-Authored-By` trailers in commits.
