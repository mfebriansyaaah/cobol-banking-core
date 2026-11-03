# Developer shortcuts (P1-7). Every target documents its prerequisites;
# `make bootstrap` is the zero-to-green path from a clean checkout.
.PHONY: help bootstrap db-up db-reset test-fast test-db test-full lint coverage

help:
	@echo "make bootstrap  - dependencies, DB, build, fast suite (all in one)"
	@echo "make db-up      - start the Docker Compose test database"
	@echo "make db-reset   - reprovision the test database (schema + seed)"
	@echo "make test-fast  - fast suite (no DB suites; set SKIP_BUILD= to build)"
	@echo "make test-db    - DB fleet (needs the test database, see db-up)"
	@echo "make test-full  - everything: fast + DB + integration + gateway"
	@echo "make lint       - shell + JS + format checks"
	@echo "make coverage   - gateway coverage (needs a built binary and DB)"

bootstrap:
	bash scripts/dev/bootstrap.sh

db-up:
	docker compose -f docker-compose.test.yml up -d

db-reset:
	bash scripts/dev/setup-test-db.sh

test-fast:
	SKIP_BUILD=1 tests/run_all.sh fast

test-db:
	tests/run_all.sh db

test-full:
	tests/run_all.sh full

lint:
	bash scripts/ci/lint.sh
	npm run lint
	npm run format:check

coverage:
	bash scripts/ci/coverage.sh --gateway-only
