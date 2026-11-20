.PHONY: all help setup deps audit fmt fmt-check lint test coverage compile ci

MIX ?= mix

all:
	$(MAKE) fmt
	$(MAKE) ci

help:
	@echo "Targets: setup, deps, audit, fmt, fmt-check, lint, test, coverage, ci"

setup:
	$(MIX) setup

deps:
	$(MIX) deps.get

# Fails when a locked package has a security advisory or is retired.
audit:
	$(MIX) hex.audit

fmt:
	$(MIX) format

fmt-check:
	$(MIX) format --check-formatted

lint:
	$(MIX) credo

test:
	$(MIX) test

coverage:
	$(MIX) coveralls.multiple --type html --type lcov

compile:
	env MIX_ENV=test $(MIX) compile --warnings-as-errors

ci:
	$(MAKE) deps
	$(MAKE) audit
	env MIX_ENV=test $(MIX) ecto.reset
	$(MAKE) compile
	$(MAKE) fmt-check
	$(MAKE) lint
	$(MAKE) coverage
