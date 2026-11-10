# templates

Filled in with Weinig's palette at build time (`programs.weinig.theme.render` and `renderIn`, for a
mode), in matugen's syntax. `../mode.nix` makes them follow dark and light: Ghostty and Zed have a theme
for each mode, Firefox and Obsidian ask for each by name, and the rest are this mode's files, through a link
in `~/.local/state/weinig/theme`.
Each is wired up by the module named after its target (`../terminal.nix`, `../gtk.nix`, `../firefox.nix`,
...).

Where they come from:

- `gtk3-base.css`, `gtk4-base.css`: noctalia's built-in GTK templates (MIT, © its authors).
- `zed.json`, `firefox-userContent.css`: noctalia's community catalog
  (https://api.noctalia.dev/templates/{zed,zen-browser}), copied 2026-10-07 and since reworked:
  semantic colors and content/chrome tones. The color variables moved into `firefox-colors.css`, and
  the userContent dropped what was only for Zen.
- `ghostty`, `qtct.conf`, `eza-theme.yml`, `gtk3-overrides.css`, `gtk4-overrides.css`, `niri.kdl`: own.
- `numix-folders.sed`: own, recolors Numix's folder icons (`../icons.nix`).
- `obsidian-border.css`: own, for the Border theme, which is recolored through Style Settings (see
  the file). Switched on once by hand in Settings > Appearance > CSS snippets.
