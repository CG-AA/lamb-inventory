# roles/grub/files/

Drop the GRUB menu background image here as `grub-background.png`
(or change `grub_background_src` in defaults).

- Formats GRUB accepts: PNG, JPEG, TGA.
- Ideal size: match the machine's `grub_gfxmode` (cracker: 1920x1200, its
  panel's native resolution — see `host_vars/cracker.yml`).
- The menu is hidden by default — the picture shows when you reveal the menu
  with Shift/Esc during the 1-second boot window (grub_hidden_timeout).

Until an image is present the role skips `GRUB_BACKGROUND` cleanly.
