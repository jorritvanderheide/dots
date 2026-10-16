{
  inputs,
  lib,
  ...
}:
{
  # The fonts and cursor, and noctalia's colors from the wallpaper: the
  # rules every target's template shares. Each target has a file of its own
  # here, with its template and settings.
  flake.nixosModules.theming =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      options.my.theming.fonts = lib.mkOption {
        type = lib.types.attrs;

        default = {
          size = 11.5;

          emoji = {
            name = "Noto Color Emoji";
            package = pkgs.noto-fonts-color-emoji;
          };

          monospace = {
            name = "JetBrainsMono Nerd Font Mono";
            package = pkgs.nerd-fonts.jetbrains-mono;
          };

          sansSerif = {
            name = "Rubik";
            package = pkgs.rubik;
          };

          serif = {
            name = "DejaVu Serif";
            package = pkgs.dejavu_fonts;
          };
        };

        description = "The fonts every target uses (name and package for each family) and their size in points.";
      };

      config = {
        fonts.fontconfig = {
          enable = true;
          antialias = true;

          defaultFonts = lib.genAttrs [ "emoji" "monospace" "sansSerif" "serif" ] (family: [
            fonts.${family}.name
          ]);

          hinting = {
            enable = true;
            style = "none";
          };

          subpixel = {
            lcdfilter = "none";
            rgba = "rgb";
          };
        };

        fonts.packages = map (family: fonts.${family}.package) [
          "emoji"
          "monospace"
          "sansSerif"
          "serif"
        ];

        home-manager.sharedModules = [
          (
            { config, lib, ... }:
            {
              programs.noctalia.settings.shell.font_family = fonts.sansSerif.name;

              # Read by libadwaita apps; the interface font is gtk.font (gtk.nix).
              dconf.settings."org/gnome/desktop/interface" = {
                document-font-name = "${fonts.serif.name} ${toString (fonts.size - 1)}";
                monospace-font-name = "${fonts.monospace.name} ${toString fonts.size}";
              };

              # Home-manager rewrites dconf's gtk-theme (gtk.nix) on every
              # activation, which would flip apps back to dark while light
              # mode is toggled on. Re-applying the templates re-runs
              # noctalia's gtk hook and color-scheme sync with the current
              # mode. Fails harmlessly when noctalia isn't running yet (at
              # boot it applies on startup).
              home.activation.noctaliaTemplatesApply =
                lib.hm.dag.entryAfter
                  [
                    "dconfSettings"
                    "noctaliaConfigReload"
                  ]
                  ''
                    run ${lib.getExe config.programs.noctalia.package} msg templates-apply || true
                  '';

              home.pointerCursor = {
                enable = true;
                gtk.enable = true;
                name = "Capitaine Cursors (Nord)";
                package = pkgs.capitaine-cursors-themed;
                size = 32;
              };

              # The built-in niri template's post hook adds this include to
              # config.kdl when missing; declaring it here makes the hook a
              # no-op, since home-manager's copy is read-only.
              # optional=true: noctalia.kdl only exists once noctalia has run,
              # and a plain include of a missing file fails niri's config
              # validation. Appended at mkOptionDefault so it lands after (and
              # overrides) the border colors in compositor.nix.
              programs.niri.config = lib.mkOptionDefault [
                (inputs.niri-flake.lib.kdl.leaf "include" [
                  { optional = true; }
                  "noctalia.kdl"
                ])
              ];

              # Colors come from the current wallpaper: noctalia generates a
              # palette from it and renders it into the templates whenever
              # the wallpaper changes.
              # Dark by default; Mod+T (keybinds.nix) flips to light on
              # purpose, e.g. for glare. Every template renders the current
              # mode, and noctalia also sets dconf's color-scheme, which apps
              # that "follow the system" (Zed, Zen, Obsidian) read through the
              # portal.
              programs.noctalia.settings.theme = {
                mode = "dark";
                source = "wallpaper";

                # noctalia's own scheme rather than a Material You one: softer
                # surfaces at both ends (not near-white/near-black), tinted
                # with the wallpaper's colors.
                wallpaper_scheme = "faithful";

                templates = {
                  # All templates share one set of rules: chrome
                  # (panels, sidebars, toolbars, bars) on the wallpaper's
                  # middle surface tone; content (editor, terminal, notes,
                  # pages, lists) one step further out (lightest in light mode,
                  # darker in dark mode); meaning (errors, git, ANSI, syntax)
                  # from custom_colors; accent used as text darkened in
                  # light mode. Each template file explains its specifics, and
                  # noctalia-templates/README.md says where each came from.
                  #
                  # The Zed and Zen templates are vendored rather than enabled
                  # as community templates: those are downloaded at runtime,
                  # and the Zen one's hook rewrites userChrome.css/user.js,
                  # which home-manager owns read-only. Zen's profile files
                  # (zen.nix) import the rendered CSS instead.
                  enable_community_templates = false;

                  # Ghostty and Qt use own templates instead (terminal.nix,
                  # qt.nix).
                  builtin_ids = [
                    "gtk3"
                    "gtk4"
                    "niri"
                  ];

                  # Color that carries meaning (terminal ANSI, syntax,
                  # diagnostics, git status) uses these fixed hues instead of
                  # the wallpaper palette, whose "green" is whatever hue the
                  # wallpaper has. noctalia expands each into Material tones
                  # (tone 80 dark / 40 light, so contrast is fixed) as
                  # colors.<name>, on_<name>, <name>_container and
                  # on_<name>_container, usable from user templates only.
                  # Base hues are One Dark-like. blend harmonizes the hue up to
                  # ~15 degrees toward the wallpaper. Off for the signal colors
                  # (error, warning, success, diff), where a pull toward pink
                  # or teal would blur the meaning, and for orange and cyan,
                  # which some wallpapers pulled into yellow/red and blue. On
                  # only for blue and purple, whose bases are spread apart so
                  # they stay distinct. Checked on all wallpapers: every pair
                  # of hues stays at least ~21 degrees apart.
                  custom_colors = {
                    blue = {
                      blend = true;
                      color = "#5a7fe6";
                    };

                    cyan = {
                      blend = false;
                      color = "#3fb0b8";
                    };

                    green = {
                      blend = false;
                      color = "#5fae5a";
                    };

                    orange = {
                      blend = false;
                      color = "#d9773c";
                    };

                    purple = {
                      blend = true;
                      color = "#b86bd9";
                    };

                    red = {
                      blend = false;
                      color = "#e05561";
                    };

                    yellow = {
                      blend = false;
                      color = "#d9b63c";
                    };
                  };
                };
              };
            }
          )
        ];
      };
    };
}
