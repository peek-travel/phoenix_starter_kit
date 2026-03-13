---
name: coverage
description: Check and increase test coverage to 100%. Use when coverage is below 100% or after writing new code. Identifies uncovered files, writes tests one file at a time, and repeats until fully covered.
---

# Coverage Skill

You are tasked with bringing test coverage to 100%. Work through uncovered files one at a time until every file is fully covered.

## Steps

1. **Get a coverage overview.** Run:
   ```bash
   mix coveralls
   ```
   Review the summary table. Identify all files below 100% coverage. If the user specified a file, start there — otherwise pick the file with the lowest coverage first.

2. **Get detailed coverage for the target file.** Run:
   ```bash
   mix coveralls.detail --filter <filename_without_extension>
   ```
   This shows line-by-line coverage. Note which lines are marked as missed.

3. **Read the source file** to understand the uncovered code paths — what conditions, branches, or error cases are not tested.

4. **Read the existing test file** (if one exists) for context on patterns, fixtures, and helpers already in use.

5. **Write tests** to cover the missing lines:
   - Follow existing test patterns in the file (describe blocks grouped by function, fixtures, etc.)
   - Use the project's testing conventions from CLAUDE.md (Mimic for mocking, fixtures in `test/support/fixtures/`)
   - Focus on exercising the specific uncovered branches/conditions
   - Don't add redundant tests for already-covered code

6. **Verify coverage improved** by re-running:
   ```bash
   mix coveralls.detail --filter <filename_without_extension>
   ```
   If the file is not yet at 100%, go back to step 3 and cover the remaining lines.

7. **Once the file reaches 100%, move to the next uncovered file.** Repeat steps 2–6 for each file until all files are at 100%.

8. **Run the full check** to make sure nothing is broken:
   ```bash
   ./bin/check
   ```

## Important Notes

- Always use `mix coveralls` commands (not `mix test --cover`) — this project uses ExCoveralls.
- Work one file at a time. Don't try to cover everything at once.
- If a file is at 100% already, skip it and move on.
- When writing tests, keep them focused and minimal — cover the missed lines without over-testing.
