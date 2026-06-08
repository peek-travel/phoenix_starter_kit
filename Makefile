.PHONY: all help setup deps fmt fmt-check lint test coverage compile ci

MIX ?= mix

all:
	$(MAKE) fmt
	$(MAKE) ci

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

compile:
	env MIX_ENV=test $(MIX) compile --warnings-as-errors

ci:
	$(MAKE) deps
	env MIX_ENV=test $(MIX) ecto.reset
	$(MAKE) compile
	$(MAKE) fmt-check
	$(MAKE) lint
	$(MAKE) coverage
