# Changelog

## Unreleased

### Changed

- Replaced `bin/check` script with a `Makefile`. Run `make` (or `make ci`) instead of `./bin/check` for the full format + lint + coverage check. Other useful targets: `make fmt`, `make lint`, `make test`, `make coverage`, `make setup`.
- Updated `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `architecture.md`, augment rules, and Claude skills to reference `make` instead of `./bin/check`.
- Updated `starter-kit-update` skill to parse and apply `[DOWNSTREAM INSTRUCTIONS]` blocks from starter kit commit messages.
