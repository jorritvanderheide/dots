# templates

Filled in with Weinig's palette at build time (`programs.weinig.theme.render`), in matugen's syntax.
Each is wired up by the module named after its target (`../terminal.nix`, `../gtk.nix`, `../zen.nix`,
...).

Where they come from:

- `gtk3-base.css`, `gtk4-base.css`: noctalia's built-in GTK templates (MIT, © its authors).
- `zed.json`, `zen-userChrome.css`, `zen-userContent.css`: noctalia's community catalog
  (https://api.noctalia.dev/templates/{zed,zen-browser}), copied 2026-10-07 and since reworked:
  semantic colors and content/chrome tones. The Zen color variables moved into `zen-colors.css`.
- `ghostty`, `qtct.conf`, `eza-theme.yml`, `gtk3-overrides.css`, `gtk4-overrides.css`: own.
- `numix-folders.sed`: own, recolors Numix's folder icons (`../icons.nix`).
- `obsidian-border.css`: own, for the Border theme, which is recolored through Style Settings (see
  the file). Switched on once by hand in Settings > Appearance > CSS snippets.
