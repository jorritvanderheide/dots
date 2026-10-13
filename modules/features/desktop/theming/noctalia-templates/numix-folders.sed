# sed script rendered by noctalia (theming/icons.nix). Its post hook runs it
# over Numix's custom folder icons, whose colors are placeholders: 1 is the
# front, 2 the back, 3 the symbol on the front. Same tones in both modes, like
# Numix's own folders, and the same steps between them as its orange set
# (front lightest, symbol a muted mid tone).
s/replacecolour1/{{palettes.primary.80.hex}}/g
s/replacecolour2/{{palettes.primary.70.hex}}/g
s/replacecolour3/{{palettes.primary.50.hex | desaturate 20}}/g
