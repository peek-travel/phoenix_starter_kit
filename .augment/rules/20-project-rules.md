---
type: "always_apply"
---

# Project Rules — Phoenix Starter Kit

## Commands & CI
- **ALWAYS run `./bin/check` before commit/push** (format, Credo, tests).
- **ALL warnings, errors, and Credo issues MUST be fixed** - no exceptions!
- **Remove ALL `IO.inspect` calls** from production code.
- **Fix ALL compiler warnings**

## Web / Phoenix
- Controllers stay thin; all business logic lives in contexts.
- Consistent result shape: `{:ok, _}` / `{:error, _}`; handle in controllers with pattern matching.

## Testing Patterns
- Use fixtures/factories; destructure `ctx` on the first line of tests.
- Prefer single, structural map assertions; sort lists before asserting list contents.
- For context modules, group tests by function using `describe "fn_name/arity" do ... end` and keep all tests for that function inside the block. One function = one describe block.
- Production code must not contain test-only logic or comments (e.g., "for tests"); handle test requirements in fixtures/factories or test setup.
- When testing html output, never pattern match directly on the entire html generated. Instead, add `data-integration` attrs to MISSION-CRITICAL dom elements that contain MISSION-CRITICAL data you want to test agains and use `text_for_integration_test_element` test helper. BAD: assert html =~ "1". GOOD: assert text_for_integration_test_element('num-bookings') == "1".

## Documentation
- **Architecture docs:** Update `docs/architecture.md` when changing module boundaries, schemas/migrations, or public interfaces; otherwise add “no architecture impact”.

## Commit Message
- Clear and descriptive subject; reference issue/ticket when relevant.

## Testing
- Per-file coverage locally: `mix coveralls.detail --filter <file-name.ex>`
- Use Mimic for module/function stubbing
- Always use factories/fixtures and include a small, clean `setup/1`
- Use Phoenix's internal dev mailbox for email testing in development
