# Inventory & plays

Classic Ansible is many machines running the same play. This repo is the
opposite — few machines, many *different* plays — so the structure optimizes
for adding kinds-of-play, not fleet size.

## The taxonomy

- **A group is a machine purpose** (`workstation`, later `laptop`, `server`).
  A host joins exactly one purpose group.
- **Each purpose has one play**: `playbooks/<purpose>.yml`, targeting
  `hosts: <purpose>`. It's a plain `roles:` list — composition, order and
  tags live there, logic lives in roles.
- **`playbooks/site.yml` imports every purpose play.** Running site.yml on a
  mixed inventory gives each host exactly its purpose's roles. This is the
  default entry point (`make run`).
- **Ad-hoc/operational plays live in `playbooks/ops/`** and are run directly
  (`playbooks/ops/upgrade.yml`). They are *never* imported by site.yml:
  provisioning describes state you converge to; ops plays perform actions you
  choose to take now. Target `hosts: all` (narrow with `--limit`) unless the
  action is purpose-specific.

## Variable layering

Low → high precedence; each layer answers a different question:

| Layer | Question it answers | Example |
|---|---|---|
| role `defaults/` | what's a sane host-agnostic fallback? | `grub_gfxmode: auto` |
| `group_vars/all.yml` | what's true for every machine of mine? | git identity, `font_mono_family` |
| `group_vars/<purpose>.yml` | what does this kind of machine want? | server: `zsh_install_starship: false` |
| `host_vars/<host>.yml` | what's true of this hardware only? | `grub_gfxmode: "1920x1200"`, `zsh_badapple` |
| `-e` / play `vars:` | what am I overriding right now? | one-off experiments |

Rules of thumb: a value repeated in two host_vars files wants to move up a
layer; a default that would be wrong on a bare VM wants to move down.
Identity-like values (PII) never go in role defaults — a fresh clone must not
ship someone's email.

## New play, new role, or new tag?

- **New purpose play** when a *kind of machine* appears (first server). Add
  the group in `inventory.yaml`, write `playbooks/<purpose>.yml` composing
  existing roles (+ `group_vars/<purpose>.yml` for its choices), import it
  from site.yml. Roles are already purpose-agnostic — reuse, don't fork them.
- **New ops play** when you need a *verb* (upgrade, backup, cert renewal) —
  something you run *at* machines occasionally rather than state they hold.
  If an ops play starts encoding state, that part belongs in a role.
- **New role** when provisioning grows a new *concern* (a program, a
  subsystem). `make new-role NAME=...`, then see CONTRIBUTING.md. Keep roles
  single-concern: "zsh setup" is one role, "my whole desktop" is not.
- **A tag is never created alone** — every role gets its own tag when wired
  into a play, plus at most a small number of shared *aspect* tags (`boot`)
  when several roles form one logical slice you re-run together. Tags are
  for slicing an existing play (`make tags TAGS=boot`), not for modelling
  purposes — if you're reaching for a tag to make one play behave like two,
  you want two plays.

## Growing checklist (new purpose)

1. `inventory.yaml`: add the group + host(s).
2. `playbooks/<purpose>.yml`: compose roles, tag each.
3. `playbooks/site.yml`: add the import.
4. `group_vars/<purpose>.yml`: the purpose's variable choices (optional).
5. `make check` — confirm other purposes' hosts are untouched.
