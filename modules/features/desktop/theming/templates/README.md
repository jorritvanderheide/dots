# templates

Filled in with Weinig's palette at build time (`programs.weinig.theme.render` and `renderIn`, for a
mode), in matugen's syntax, for the apps whose colours Weinig's own theming doesn't reach. Ghostty and
Zed have a theme for each mode, Firefox and Obsidian ask for each by name, and eza's is this mode's
file, through Weinig's link in `~/.local/state/weinig/theme` (`../mode.nix`). GTK, Qt and niri are
Weinig's (`theme.apps`). Each is wired up by the module named after its target (`../terminal.nix`,
`../firefox.nix`, ...).

Where they come from:

- `zed.json`, `firefox-userChrome.css`, `firefox-userContent.css`: noctalia's community catalog
  (https://api.noctalia.dev/templates/{zed,zen-browser}), copied 2026-10-07 and since reworked:
  semantic colors and content/chrome tones. The color variables moved into `firefox-colors.css`, and
  both dropped what was only for Zen.
- `ghostty`, `eza-theme.yml`: own.
- `numix-folders.sed`: own, recolors Numix's folder icons (`../icons.nix`).
- `obsidian-border.css`: own, for the Border theme, which is recolored through Style Settings (see
  the file). Switched on once by hand in Settings > Appearance > CSS snippets.
