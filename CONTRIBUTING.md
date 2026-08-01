# Contributing

Personal repo, but future-me counts as a contributor. The rules below keep
the repo coherent as it grows.

## Dev setup

```sh
make deps            # ansible-galaxy collections + pre-commit hook install
make lint            # yamllint + ansible-lint (production profile)
make syntax          # playbook syntax check
make check           # full dry run against the inventory
```

CI (`.github/workflows/lint.yml`) runs the same gate on every push/PR:
pre-commit (hygiene + yamllint + ansible-lint) and the syntax check.

## Adding a role

Generate the skeleton, then work through the checklist:

```sh
make new-role NAME=myrole
```

1. **Defaults first** (`defaults/main.yml`): every public variable, prefixed
   `myrole_`, each with a rationale comment; end with a `# Full revert:` note.
   Defaults must be host-agnostic — machine specifics belong in host_vars,
   user-scoped truths in group_vars (see docs/inventory-and-plays.md).
2. **Tasks** (`tasks/main.yml`): follow docs/conventions.md — FQCN modules,
   per-task `become` with a reason, warn-and-skip over fail, read-then-write
   guards around non-idempotent CLIs.
3. **Metadata**: `meta/main.yml` ships with the skeleton (keep the `common`
   dependency and its `tags: [always]` — see the comment in the file);
   fill in `meta/argument_specs.yml` for every public variable so
   ansible-core validates inputs at run time.
4. **Wire it into the play** for the purposes that want it, with its own tag:
   `- role: myrole` / `tags: [myrole]` in `playbooks/<purpose>.yml`.
5. **Verify**: `make lint`, `make syntax`, `make tags TAGS=myrole` twice —
   the second run must report `changed=0`.

## Lint exceptions

`skip_list` in `.ansible-lint` stays empty. A rule that genuinely doesn't fit
gets an inline `# noqa: <rule>` on the task line, with a comment JUSTIFYING
it next to it — every existing noqa carries one; keep it that way.

## Commits

Imperative subject, body explains *why*. If a change alters what lands on a
machine, say so (files written, packages installed, revert path).
