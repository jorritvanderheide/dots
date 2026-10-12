# noctalia templates

Rendered by noctalia from the wallpaper's palette. `../theming.nix` wires them
up and holds the color rules they share; each file's header explains its
specifics.

Where they come from:

- `zed.json`, `zen-userChrome.css`, `zen-userContent.css`: noctalia's
  community catalog (https://api.noctalia.dev/templates/{zed,zen-browser}),
  copied 2026-10-07 and since reworked: semantic colors, content/chrome
  tones, light-mode accent text (Zed). The Zen color variables moved into
  `zen-colors.css`.
- `ghostty`, `qtct.conf`: own, replacing noctalia's built-in Ghostty and Qt
  templates (noctalia 5.2.1).
- `fish.fish`: own, prompt accent only.
- `eza-theme.yml`: own, directory accent only.
- `gtk3-overrides.css`, `gtk4-overrides.css`: own, layered on top of the
  built-in GTK templates, which stay enabled.
- `obsidian-border.css`: own, for the Border theme, which is recolored
  through Style Settings (see the file). Switched on once by hand in
  Settings > Appearance > CSS snippets.
