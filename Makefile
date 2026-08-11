.PHONY: test test-one lint

test:
	./tests/run.sh

test-one:
	./tests/run.sh tests/$(SPEC)

lint:
	@echo "No linter configured (see AGENTS.md)."
