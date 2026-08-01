# lamb-inventory

Ansible provisioning for TheLamb's machines. One repo, many *different*
plays: machines are grouped by **purpose** (workstation, later laptop/server),
each purpose has its own play, and ad-hoc operational plays live alongside —
see [docs/inventory-and-plays.md](docs/inventory-and-plays.md).

## Quickstart

```sh
make deps        # install required collections + git pre-commit hook
make check       # dry run with diff — see what would change
make run         # apply everything (playbooks/site.yml)

make tags TAGS=kitty,fonts   # re-run a slice
make ops-upgrade             # ad-hoc play: OS package upgrade
make help                    # everything else
```

Run from the repo root — `ansible.cfg` is only picked up from the CWD (the
Makefile targets guarantee this).

`check`, `run` and `tags` ask for your sudo password once per run (the roles
install packages and write under `/etc`). `make syntax` and `make lint` never
prompt. Passwordless sudo? Press enter, or export
`ANSIBLE_BECOME_ASK_PASS=False`.

## Layout

```
ansible.cfg            inventory/roles path wiring (run from repo root)
inventory.yaml         hosts, grouped by machine purpose
group_vars/all.yml     user-scoped values shared by every machine
host_vars/<host>.yml   hardware/machine specifics
playbooks/site.yml     everything — imports one play per purpose group
playbooks/<purpose>.yml    the play for one purpose (workstation.yml, ...)
playbooks/ops/         ad-hoc operational plays, run directly
roles/                 one role per concern; roles/common is shared plumbing
docs/                  conventions, grouping guidelines, shell design
.role-skeleton/        template for `make new-role NAME=...`
```

## Provisioning a new machine

1. Add the host to its purpose group in `inventory.yaml` (create the group +
   `playbooks/<purpose>.yml` + a `site.yml` import if it's a new purpose).
2. Put hardware specifics in `host_vars/<host>.yml` — role defaults stay
   host-agnostic on purpose, so a bare host still provisions sanely.
3. `make check`, then `make run` (or `--limit <host>`).

Roles degrade rather than fail on hosts that miss their target: GRUB/Plymouth
skip on containers, the bootlogo is DMI-gated, Plasma wiring only fires where
plasmashell exists. A recap full of `skipped` on a VM is working as intended.

## Working on the repo

Lint gate (also enforced by CI): `make lint`. Conventions the code follows —
and a checklist for adding roles — are written down:

- [CONTRIBUTING.md](CONTRIBUTING.md) — dev setup, new-role workflow
- [docs/conventions.md](docs/conventions.md) — the house style for roles
- [docs/inventory-and-plays.md](docs/inventory-and-plays.md) — groups, plays,
  variable layering; when to add a play vs role vs tag
- [docs/shell.md](docs/shell.md) — the `-lamb` shell rc design
