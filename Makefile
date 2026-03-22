.PHONY: help all setup deps fmt fmt-check lint test coverage ci

MIX ?= mix

help:
	@echo "Targets: setup, deps, fmt, fmt-check, lint, test, coverage, ci"

setup:
	$(MIX) setup

deps:
	$(MIX) deps.get

fmt:
	$(MIX) format

fmt-check:
	$(MIX) format --check-formatted

lint:
	$(MIX) credo

test:
	$(MIX) test

coverage:
	$(MIX) coveralls.lcov

ci:
	$(MAKE) deps
	env MIX_ENV=test $(MIX) ecto.reset
	$(MAKE) fmt-check
	$(MAKE) lint
	$(MAKE) coverage

all: ci
