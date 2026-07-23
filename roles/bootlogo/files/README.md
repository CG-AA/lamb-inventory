# roles/bootlogo/files/

Drop the custom firmware boot logo here as `lenovo-logo.bmp`
(or change `bootlogo_image_src` in defaults).

Firmware constraints on the ThinkBook 14 G6 IRL (from its LBLDESP variable):

- Formats: **JPG, GIF, BMP only** — PNG is NOT accepted (bitmask 0x19).
- Max 1920x1200; recommended <= 768px wide (factory logo is 768x256).
- JPG for photos/gradients, BMP for lossless; avoid GIF (256 colours).

The role stages the image at /boot/efi/EFI/Lenovo/Logo/ on this machine only
(DMI-gated). Activating it (LBLDESP enable byte) is a deliberate manual step —
see the role defaults for the vetted tool link.
