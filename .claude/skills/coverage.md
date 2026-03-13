---
name: coverage
description: Check and increase test coverage for specific files or the whole project. Use when coverage is below 100% or after writing new code.
---

# Coverage Skill

You are tasked with checking and increasing test coverage.

## Steps

1. **Identify files with missing coverage.** Run:
   ```bash
   mix coveralls.detail --filter <filename_without_extension>
   ```
   If the user provided specific file(s), filter to those. Otherwise, run `mix coveralls` and look for files below 100%.

2. **Analyze uncovered lines.** Read the output to identify which lines/branches are not covered. The coveralls output shows line-by-line coverage with markers for missed lines.

3. **Read the source file** to understand the uncovered code paths — what conditions, branches, or error cases are not tested.

4. **Read the existing test file** for context on patterns, fixtures, and helpers already in use.

5. **Write tests** to cover the missing lines:
   - Follow existing test patterns in the file (describe blocks grouped by function, fixtures, etc.)
   - Use the project's testing conventions from CLAUDE.md
   - Focus on exercising the specific uncovered branches/conditions
   - Don't add redundant tests for already-covered code

6. **Verify coverage improved** by re-running:
   ```bash
   mix coveralls.detail --filter <filename_without_extension>
   ```

7. **Repeat** until the file reaches 100% coverage.

8. **Run the full check** to make sure nothing is broken:
   ```bash
   mix compile --warnings-as-errors && mix format --check-formatted && mix credo && mix test
   ```
