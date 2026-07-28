# lamb-inventory

Ansible inventory that provisions personal Debian/Ubuntu machines. `cracker` is
a laptop applied locally; `glowing-glass` is a headless box reached over SSH.
Run it with `ansible-playbook playbook.yaml` (ansible.cfg wires up the
inventory and roles path), or a slice with `--tags kitty` / `--tags boot`.

## Contracts every role must follow

These are not style preferences — each one exists because breaking it caused a
real regression. Read this section before adding or editing a role.

### 1. Roles are host-agnostic; the machine's truths live outside them

A role must run unchanged on a laptop, a VM, a container or a headless server.
Nothing machine-specific belongs in `roles/*/defaults/main.yml`.

| What | Where | Example |
|---|---|---|
| One machine's truth | `host_vars/<host>.yml` | `grub_gfxmode: "1920x1200"` (cracker's panel) |
| A whole group's policy | `group_vars/<group>.yml` | `fonts_manage: false` (all headless hosts) |
| Which groups a host is in | `inventory.yaml` groups | `glowing-glass` under `headless` |

Adding another headless machine should be **one line in `inventory.yaml`** (plus
its profiles) and nothing else. If it needs more than that, the policy was in
the wrong place.

**Two axes, one direction each.** A host has exactly one *class* and any number
of *profiles*:

| Axis | Groups | Answers | Sets `<role>_manage` |
|---|---|---|---|
| Class | `workstations`, `headless` | what the machine **is** | only → `false` |
| Profile | `development`, `robotics`, `cosmetics` | what it's **for** | only → `true` |

Keeping assignment one-way is load-bearing, not tidiness. Two groups at the same
depth setting the same var resolve **alphabetically**, silently — if `cosmetics`
and `headless` both reached for `fonts_manage`, `headless` would win purely
because h > c, and nothing would say so. One-way means the collision cannot
arise. `host_vars/` still beats every group.

Read a host's groups back out of the inventory rather than grepping:
`ansible-inventory --graph`, or `ansible-inventory --host cracker` for the fully
merged vars.

### 2. Every role ships `<role>_manage`, gated in the playbook

Each role's `defaults/main.yml` defines `<role>_manage`, and `playbook.yaml`
gates the role on it:

```yaml
- role: fonts
  when: fonts_manage | bool
  tags: [fonts]
```

Which way the default points follows from §1's two axes:

* **baseline roles default `true`** — wanted on any machine, a *class* opts out
  (`fonts_manage: false` for headless);
* **profile-only roles default `false`** — too big or too specific to install by
  accident, a *profile* opts in (`ros2_lyrical_manage`, `gazebo_manage` via
  `group_vars/robotics.yml`; `bootlogo_manage`, `grub_background_enabled`,
  `zsh_badapple` via `group_vars/cosmetics.yml`).

A profile gates what a role **draws**, never whether a correctness-critical role
**runs**. `cosmetics` turns on the GRUB background and the boot logo, but
`grub_manage` and `plymouth_manage` stay baseline `true` everywhere — the
composition guard in §4 is what keeps another tool's `resume=` alive, and a host
nobody looks at needs that protection just as much.

Either way, this is what lets a group turn a role off (or on) without editing
its tasks. `fonts`
originally had no such toggle, so a headless host had no way to decline a
Nerd Font install (~38 MB on disk, from a ~250 MB-unpacked archive) it could
never rasterise. Roles with an internal
applicability gate (`grub`, `plymouth`) keep their own `_manage` check too, so
they stay correct if included directly.

Distinguish the two kinds of gate:

* `<role>_manage` — **policy**: "we choose not to do this here."
* `<role>_applicable` / `kitty_has_de` / `bootlogo_enabled` — **capability**:
  "this machine cannot do this." Capability gates warn once and skip; they
  never fail the play.

### 3. Host detection lives only in `roles/facts`

`roles/facts` runs first, `tags: [always]` (so `--tags kitty` still gets its
vars), and probes the machine once: `kitty_has_de`, `lamb_has_plasma`,
`grub_applicable`, `plymouth_applicable`. Roles **consume** those vars and must
never re-probe. Every probe is guarded by "is this var already set?", so an
explicit value in inventory / group_vars / host_vars always beats the detection.

Need a new capability? Add it to `roles/facts`, not to the role that happens to
want it first — kitty and fonts used to stat `/usr/bin/plasmashell` separately.

One consequence to keep in mind: the roles now *depend* on `roles/facts` having
run. Including grub/plymouth/kitty/fonts directly (outside `playbook.yaml`)
leaves their capability vars unset and they will warn-and-skip or fail on an
undefined var. That is by design — run them through the playbook.

Detection must key on the thing that is actually load-bearing. The old DE probe
accepted `systemctl get-default == graphical.target`, which Ubuntu leaves set on
server installs that have never had a display manager — that is how a headless
box talked the kitty role into installing a GPU terminal emulator. It now keys
on `/etc/systemd/system/display-manager.service` alone.

### 4. Files in a shared namespace inherit and append — never plain-assign

`/etc/default/grub.d/` is shared: `lamb-machine` owns `90-`, the kdump-tools
package owns its own, we own `95-`. `grub-mkconfig` sources them in glob order,
so a later file that writes

```sh
GRUB_CMDLINE_LINUX_DEFAULT="quiet"        # WRONG
```

silently deletes everything the earlier files added. This exact line ate
`90-lamb-machine.cfg`'s `resume=`/`resume_offset=` on glowing-glass and left
hibernation resume dead (`/sys/power/resume` reading `0:0`) until it was found.

The template now inherits `$GRUB_CMDLINE_LINUX_DEFAULT`, strips only the tokens
the role claims in `grub_cmdline_remove`, and appends `grub_cmdline_add`. A
composition guard task at the end of `roles/grub/tasks/main.yml` sources the
drop-ins with and without ours and **fails the run** if any token another tool
contributed went missing. Keep that guard working; it is the general defence,
not a one-off patch.

### 5. Leave-in-place

Roles converge state, they do not clean up. Turning `<role>_manage` off stops
managing something; it never uninstalls it (see `zsh_badapple`'s note about
never deleting frames). Removing what a previous run installed is a deliberate,
documented one-off, run by hand — not a task that fires on the next play.

## Conventions

* Prefer the real mechanism over editing files: `update-locale`, `update-grub`,
  `kwriteconfig6`, `update-alternatives` (via `community.general.alternatives`),
  `git_config`. Where such a tool is not idempotent (`update-locale`,
  `kwriteconfig6`), guard the write behind a read so re-runs stay green.
* Non-idempotent-by-nature `command` tasks carry `changed_when` explicitly, and
  read-only ones carry `changed_when: false` + `check_mode: false`.
* Deploy dotfiles with `become: false` — they are the user's, never root's —
  and `backup: true` on first-write so nothing is lost.
* Comment the *why*, especially load-bearing ordering (glob order in
  `grub.d`/`fonts.d`, `pre`/`post` hook placement). The existing files set the
  density; match it.
* New role checklist: `<role>_manage` default → `when:` in `playbook.yaml` →
  tag → capability gate via `roles/facts` if it can't run everywhere → revert
  instructions in the defaults header.

## Verifying a change

```sh
ansible-playbook playbook.yaml --syntax-check
ansible-playbook playbook.yaml --check --diff --limit cracker     # dry run
ansible-playbook playbook.yaml --limit cracker                    # apply
ansible-playbook playbook.yaml --limit cracker                    # must be all green
```

Idempotence (a second run reporting no changes) is the acceptance test. For
boot-related changes also confirm the *merged* result, not just the drop-in:

```sh
sh -c '. /etc/default/grub; for f in /etc/default/grub.d/*.cfg; do . "$f"; done
       echo "$GRUB_CMDLINE_LINUX_DEFAULT"'
grep -m1 -E "^\s+linux\s" /boot/grub/grub.cfg
```
