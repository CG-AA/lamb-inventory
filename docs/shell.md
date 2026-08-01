# Shell rc design — the `-lamb` contract

## The contract

Two kinds of shell config exist on a machine, with opposite ownership:

- **Managed files** — suffixed `-lamb`, deployed by roles/zsh, replaced
  wholesale on every run. Editing them on a host is futile (the role wins);
  the source of truth is `roles/zsh/files/`.
- **The user's own rc files** — `~/.zshrc`, `~/.bashrc`. The repo NEVER owns
  these. Each carries exactly one marker-delimited block
  (`# BEGIN/END lamb-inventory (roles/zsh)`) sourcing its `-lamb`
  counterpart; everything else in them is yours.

The point of the split: random installers love appending to `~/.zshrc` /
`~/.bashrc`. Under this contract that cruft lands in files the repo never
rewrites — visible with a plain diff against the stub, easy to keep or
migrate into the managed layer deliberately, and never silently clobbered by
a provisioning run.

## The layers

```
~/.zshrc  ──block──▶ ~/.zshrc-lamb ─────┐
                                        ├──▶ ~/.shellrc-lamb   (POSIX)
~/.bashrc ──block──▶ ~/.bashrc-lamb ────┘
                     ~/.zshbadapple-lamb  (sourced by zshrc-lamb; self-guarding)
```

- **`~/.shellrc-lamb`** — POSIX only, both shells: PATH (sole owner; the
  membership-checked prepend also stops nested-shell duplication), dircolors
  and aliases, portable functions, `PYENV_ROOT`.
- **`~/.zshrc-lamb`** — zsh interactive: history, completion (one styling
  block), keybindings, `pyenv init - zsh`, plugins, starship.
  Syntax-highlighting is sourced last, which leans on the ~/.zshrc block
  staying at the END of that file — if an installer appends below the block,
  move its lines above.
- **`~/.bashrc-lamb`** — bash-only machinery: `pyenv init - bash`, completion
  cloning for the `s` alias. Debian's stock `~/.bashrc` (prompt, bash
  completion) keeps doing its job above the block.

**Bash-parity policy**: anything both shells need goes in `shellrc-lamb` and
must stay POSIX (test with `sh -n`). Shell-flavoured versions of the same
tool hook (pyenv, completions) live in each shell's `-lamb` file. Don't let
one shell source the other's file — that's how the old `bashrc_lamb`-in-zsh
setup rotted.

## Migration from the old layout

Earlier revisions deployed `~/.zshrc` itself plus `.shell_common` /
`.bashrc_lamb` / `.zshbadapple`. The role migrates automatically: a
`~/.zshrc` whose checksum matches an old shipped revision (list in
`zsh_legacy_zshrc_checksums`) is reset to a comment stub; a customized one is
left alone (resolve by hand: keep your lines, keep the block last). The
superseded dotfiles are removed via `zsh_legacy_dotfiles`. If you ever ship a
new revision of a file that later gets absorbed, add its checksum/name to
those lists — that's the whole retirement mechanism.

## Future: `~/.shellrc.d/` drop-ins

Not implemented, deliberately. If per-machine or per-tool snippets multiply
(work machine vs home machine wanting different aliases), switch
`shellrc-lamb` to end with a loop over `~/.shellrc.d/*.sh` and ship snippets
as separate files. Adopt when a third "only on machine X" case appears in
`shellrc-lamb` — before that, host_vars-driven templating or plain `if`s are
less machinery. Keep drop-ins POSIX and numbered (`50-work.sh`) if ordering
ever matters.
