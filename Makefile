# Ergonomics wrapper — also pins the CWD contract: ansible.cfg is only read
# from the directory you run in, so everything here assumes the repo root.
PLAYBOOK ?= playbooks/site.yml

# BRIEF=1 turns any run into an overview. Hiding ok/skipped hosts also DEFERS
# their task banners — ansible prints a task's title only when that task has
# something to report — so a `make check BRIEF=1` recap is the list of things
# that would actually change, and --diff comes off so the hunks go with it.
# Totals for the quiet tasks are still in the PLAY RECAP. `make list` is the
# other half of the overview: every task title, in order, without running.
ifdef BRIEF
  PLAY := ANSIBLE_DISPLAY_OK_HOSTS=false ANSIBLE_DISPLAY_SKIPPED_HOSTS=false ansible-playbook
  CHECK_DIFF :=
else
  PLAY := ansible-playbook
  CHECK_DIFF := --diff
endif

.PHONY: help deps lint syntax list check run tags ops-upgrade new-role

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

list:           ## every task title the entry playbook would run (nothing runs)
	ansible-playbook $(PLAYBOOK) --list-tasks

check:          ## dry run with diff (no changes applied); BRIEF=1 for an overview
	$(PLAY) $(PLAYBOOK) --check $(CHECK_DIFF)

run:            ## apply the entry playbook; BRIEF=1 for an overview
	$(PLAY) $(PLAYBOOK)

tags:           ## run a slice, e.g. `make tags TAGS=kitty,fonts`
	$(PLAY) $(PLAYBOOK) --tags "$(TAGS)"

ops-upgrade:    ## ad-hoc play: OS package upgrade (all hosts; use --limit via ARGS)
	$(PLAY) playbooks/ops/upgrade.yml $(ARGS)

new-role:       ## scaffold roles/<NAME> from .role-skeleton, e.g. `make new-role NAME=htop`
	@test -n "$(NAME)" || { echo "usage: make new-role NAME=<role>"; exit 1; }
	ansible-galaxy role init --role-skeleton .role-skeleton --init-path roles $(NAME)
	@echo "Now work through the checklist in CONTRIBUTING.md."
