---
name: starter-kit-update
description: Backport latest commits from phoenix_starter_kit into this project. Use when you need to sync upstream starter kit changes.
---

# Starter Kit Update

You are tasked with backporting the latest changes from the `phoenix_starter_kit` repo (`https://github.com/peek-travel/phoenix_starter_kit`) into this project.

## Steps

1. **Create a feature branch.**
   Generate a short random suffix and create a new branch:
   ```bash
   git checkout -b feat/starter-kit-update-$(openssl rand -hex 4)
   ```

2. **Determine current starter kit version.**
   Read `.phoenix_starter_kit_version` — it contains the last backported commit SHA from the starter kit.

3. **Fetch the starter kit commit history.**
   Use `gh` to get the commit log on `master` from the starter kit repo, starting after the SHA in `.phoenix_starter_kit_version` up to the latest:
   ```bash
   # Get current version
   CURRENT_SHA=$(cat .phoenix_starter_kit_version | tr -d '[:space:]')

   # Get commits after our current version (oldest first)
   gh api repos/peek-travel/phoenix_starter_kit/commits?sha=master\&per_page=100 \
     --jq '.[].sha' | tac
   ```
   Filter commits to only those **after** `$CURRENT_SHA`. If there are no new commits, stop and inform the user.

4. **Review the changelog (if any).**
   Check if the starter kit has a CHANGELOG.md or release notes that provide context for the changes:
   ```bash
   gh api repos/peek-travel/phoenix_starter_kit/contents/CHANGELOG.md \
     --jq '.content' | base64 -d 2>/dev/null || echo "No changelog found"
   ```
   Use any changelog information to understand the intent behind changes.

5. **Implement changes commit-by-commit.**
   For each new commit (in chronological order):

   a. **Read the commit diff:**
      ```bash
      gh api repos/peek-travel/phoenix_starter_kit/commits/<SHA> \
        --jq '.files[] | "\(.filename)\t\(.status)\t\(.patch // "")"'
      ```

   b. **Read the commit message:**
      ```bash
      gh api repos/peek-travel/phoenix_starter_kit/commits/<SHA> \
        --jq '.commit.message'
      ```

   c. **Check for downstream instructions in the commit message.**
      Look for a section delimited by `[DOWNSTREAM INSTRUCTIONS]` ... `[/DOWNSTREAM INSTRUCTIONS]` in the commit body. If present, parse and execute those instructions on this project in addition to applying the normal diff. For example:
      ```
      Replace bin/check with Makefile

      [DOWNSTREAM INSTRUCTIONS]
      - Remove any references to `./bin/check` or `bin/check` in docs and replace with `make`
      - Update CLAUDE.md, README.md, CONTRIBUTING.md, architecture.md, and any AI rules files
      [/DOWNSTREAM INSTRUCTIONS]
      ```
      Use these instructions as added context to better understand the intent of the commit diff, then apply the changes. **Never stop to ask for confirmation** — changes made upstream in phoenix_starter_kit are intentional and every downstream project should follow them. If a specific change is ambiguous, make your best-effort judgment call and apply it. If applying it breaks something (a test fails, the mapping doesn't quite fit), fix that too as part of this step. Only if you genuinely cannot resolve it, leave a clear TODO/FIXME comment at the spot and call it out prominently in the review (step 6) — but still apply everything else. **Never silently skip a change without noting it in the review.**

   d. **Apply the changes to this project**, adapting them as needed:
      - The starter kit uses a generic app name — map files/modules to this project's equivalents
      - Detect the current project's module namespace by reading `mix.exs` (look for `defmodule <Module>.MixProject`)
      - Detect the current app name from the `:app` field in `mix.exs`
      - The starter kit module namespace is `PhoenixStarterKit`/`PhoenixStarterKitWeb` and app name is `phoenix_starter_kit` — map these to the detected project equivalents
      - Some files may not exist in this project or may have diverged significantly — use judgment
      - Skip changes that are clearly starter-kit-specific and don't apply
      - **Don't apply generated or project-shaped files as a literal patch.** Files like `mix.lock` (a different dependency tree per project) or a `Dockerfile` (which may live at a different path or have a different structure, e.g. Alpine vs Debian, different build stages, AWS Fargate vs Fly.io) can't be diffed verbatim. For these, re-derive the equivalent change in this project's actual file (e.g. run `mix deps.update` yourself instead of patching `mix.lock`; find and bump this project's own version-pin lines instead of copying the Dockerfile diff). The `[DOWNSTREAM INSTRUCTIONS]` block (if present) should tell you which files fall into this category — treat its absence as a signal that a direct diff is safe to apply.

   e. **Update `.phoenix_starter_kit_version`** with this commit's SHA.

   f. **Create a commit** with a message referencing the original starter kit commit:
      ```
      starter_kit: <original commit message>

      Backported from phoenix_starter_kit@<short-SHA>
      ```

6. **Review all changes.**
   After applying all commits, review the full diff from the branch point:
   ```bash
   git diff main...HEAD
   ```
   Assess confidence level:
   - Which changes mapped cleanly?
   - Which required adaptation?
   - Any changes skipped and why?
   - Any downstream instructions applied and how?

   Report this assessment to the user.

7. **Run the full test suite and ensure 100% coverage.**
   ```bash
   make
   ```
   If tests fail or coverage drops below 100%, fix the issues before proceeding.
   Use the `/coverage` skill if needed to bring coverage back to 100%.

8. **Push the branch.**
   ```bash
   git push -u origin HEAD
   ```

9. **Improve this skill.**
   If this run surfaced something this file didn't already cover — a new file-mapping pattern, a gotcha in how a starter kit change needed adapting, a `[DOWNSTREAM INSTRUCTIONS]` block that was ambiguous or missing something you had to guess at, a step that turned out to be wrong or incomplete — update this `SKILL.md` with that knowledge before finishing, so the next run starts smarter. Keep additions concrete and short (a bullet under "Important Notes", or a tweak to the relevant step); don't pad the file with narration. If the fix is something upstream `phoenix_starter_kit` itself should know (e.g. a commit that was missing a `[DOWNSTREAM INSTRUCTIONS]` block it needed), mention that in your report to the user rather than trying to change the upstream repo yourself.

## Important Notes

- Always work commit-by-commit to maintain a clean, reviewable history.
- Never stop mid-run to ask for confirmation — changes made upstream in phoenix_starter_kit are intentional and this skill's job is to apply them, not to gate them behind approval. Use your best judgment on ambiguous mappings, fix anything that breaks as a result, and document the judgment call in the review (step 6) instead of pausing to ask.
- If a starter kit change conflicts heavily with local customizations, adapt it as best you can rather than skipping it, and call out the conflict and how you resolved it in the review. Only skip a change if it's genuinely inapplicable (e.g. it's starter-kit-specific and this project has no equivalent), and say so explicitly in the review.
- The `.phoenix_starter_kit_version` file should be updated with each commit to track progress.
- If the backport introduces new dependencies, run `mix deps.get` after updating `mix.exs`.
- If the backport includes new migrations, note them in the review but DO NOT run them automatically.
- Downstream instructions in commit messages are authoritative — apply them even if the diff itself doesn't touch those files.
- Never apply `mix.lock` or Dockerfile diffs verbatim — re-derive the equivalent change for this project's own files (see step 5d).
- This skill file itself lives in the starter kit template, so it ships to every project created from it — keep it generically useful, not specific to any one downstream project's quirks.
