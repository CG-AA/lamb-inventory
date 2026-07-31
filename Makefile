# Ergonomics wrapper — also pins the CWD contract: ansible.cfg is only read
# from the directory you run in, so everything here assumes the repo root.
PLAYBOOK ?= playbook.yaml

.PHONY: help deps lint syntax check run tags

help:           ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

deps:           ## install required collections + lint tooling hooks
	ansible-galaxy collection install -r requirements.yml
	pre-commit install

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
