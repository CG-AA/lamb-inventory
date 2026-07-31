# Role conventions

The house style. Most of this predates the docs — it was extracted from the
inline comments of the original roles, which remain the best examples.

## Variables

- **Namespace everything** with the role prefix: `kitty_*`, `fonts_*`. No
  exceptions; a bare name is a collision waiting for a bigger inventory.
- **Internal/registered vars get a leading underscore**: `_fonts_stamp`,
  `_kitty_kdeglobals`. Underscore means "not part of the role's interface —
  never set this from inventory".
- **Defaults are the interface.** Every public variable appears in
  `defaults/main.yml` with a comment saying what it does and *why* that
  default; `vars/` is avoided (it beats inventory, which is almost never what
  a default should do).
- **Defaults are host-agnostic.** A role must run sanely with nothing but its
  defaults on a VM or container. Hardware/machine facts go in
  `host_vars/<host>.yml`; user-scoped truths (git identity, font family) in
  `group_vars/all.yml`. See docs/inventory-and-plays.md for the layering.
- End `defaults/main.yml` with a **`# Full revert:`** note — the manual
  commands that undo the role.
- Declare public variables in **`meta/argument_specs.yml`** — ansible-core
  validates them on every run, catching typos and type mistakes for free.

## Tasks

- **FQCN always**: `ansible.builtin.apt`, `community.general.alternatives`.
- **`become` per task, never play-wide**, with a reason when it's `false` in
  a root-ish context ("this is *your* dotfile, never root's").
- **Warn-and-skip beats fail.** A host that can't take a role (no GRUB, no
  Plasma, wrong DMI) gets a `debug` message saying what was skipped and how
  to force it — never a failed play. The *null-autodetect contract* is the
  standard shape: default `~` (null) means autodetect via probes +
  `set_fact`; inventory can force `true`/`false` to skip the probe.
- **Read-then-write guards** around CLIs that always rewrite
  (`kwriteconfig6`, `update-locale`): read the current value
  (`changed_when: false`, `check_mode: false`), write only on difference
  (`changed_when: true`). Keeps re-runs at `changed=0`, which is the
  regression test for the whole repo.
- **Stamp files for expensive installs** (see the fonts role): write a
  `.ansible-stamp` *after* success, gate the block on its absence, sweep
  superseded versioned directories.
- **Check mode must survive a fresh host.** A module that hard-fails when an
  earlier task only pretended (unarchive on a missing dir, alternatives on a
  missing binary) gets a probe + `not ansible_check_mode or <probe>` guard.
- **Task names are prose**, sentence-case; a templated value goes at the END
  of the name (ansible-lint `name[template]`).
- **`# noqa` needs a justification comment.** Rule-wide skips in
  `.ansible-lint` are not used.

## Shared plumbing (roles/common)

Every role depends on `common` (see any `meta/main.yml` — keep the
`tags: [always]`, the comment there explains why). It provides:

- **The target-user contract**: `common_target_user` / `common_target_home` /
  `common_kde_config_dir`. Per-user paths in role defaults derive from these,
  so provisioning a box as root for another user is ONE override.
- **One apt cache refresh per run** — role apt tasks don't carry
  `update_cache`.
- **`common_plasma_detected`** — the Plasma probe, shared by kitty and fonts.
- **`asset_probe`** (`include_role` with `tasks_from`) — the controller-side
  "does the role ship this optional asset?" check used by grub and bootlogo.

## Files and templates

- Role-shipped dotfiles are the **source of truth**; targets are replaced,
  not merged. Config the user (or other programs) own is never replaced —
  it gets a `blockinfile` marker block instead (see docs/shell.md).
- Templates carry a "Managed by Ansible — roles/<name>" header naming the
  file to edit instead.
- Optional assets (background image, logo) are probed with `asset_probe` and
  their absence degrades the role, with a note saying what to drop where.
