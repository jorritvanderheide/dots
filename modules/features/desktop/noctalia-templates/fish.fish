# Fish prompt accent rendered by noctalia (theming.nix) and run by its post
# hook. Universal variables, so every running shell picks the new accent up
# right away. Fish's default theme still fills in every other color from the
# terminal's ANSI palette (the Ghostty and Zed templates). primary is tone 80
# in dark mode and 40 in light mode, so it reads as text in both.
set -U fish_color_user '{{colors.primary.default.hex}}'
set -U fish_color_cwd '{{colors.primary.default.hex}}'
