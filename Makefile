# Ergonomics wrapper — also pins the CWD contract: ansible.cfg is only read
# from the directory you run in, so everything here assumes the repo root.
PLAYBOOK ?= playbooks/site.yml

.PHONY: help deps lint syntax check run tags ops-upgrade

help:           ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

# pre-commit is a python tool, not an ansible dependency: it may simply not be
# on PATH yet. Warn and skip rather than failing the whole target — the
# collections above are the part that `make run` actually needs, and CI runs
# the same hooks whether or not the local git hook is installed.
deps:           ## install required collections + lint tooling hooks
	ansible-galaxy collection install -r requirements.yml
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
	else \
		echo "pre-commit not on PATH — git hook NOT installed."; \
		echo "  install it (pipx install pre-commit / apt install pre-commit /"; \
		echo "  pip install --user pre-commit), then re-run 'make deps'."; \
	fi

lint:           ## yamllint + ansible-lint (same gate as CI)
	yamllint .
	ansible-lint

syntax:         ## ansible syntax check of the entry playbook
	ansible-playbook $(PLAYBOOK) --syntax-check

check:          ## dry run with diff (no changes applied)
	ansible-playbook $(PLAYBOOK) --check --diff

run:            ## apply the entry playbook
	ansible-playbook $(PLAYBOOK)

tags:           ## run a slice, e.g. `make tags TAGS=kitty,fonts`
	ansible-playbook $(PLAYBOOK) --tags "$(TAGS)"

ops-upgrade:    ## ad-hoc play: OS package upgrade (all hosts; use --limit via ARGS)
	ansible-playbook playbooks/ops/upgrade.yml $(ARGS)

new-role:       ## scaffold roles/<NAME> from .role-skeleton, e.g. `make new-role NAME=htop`
	@test -n "$(NAME)" || { echo "usage: make new-role NAME=<role>"; exit 1; }
	ansible-galaxy role init --role-skeleton .role-skeleton --init-path roles $(NAME)
	@echo "Now work through the checklist in CONTRIBUTING.md."
