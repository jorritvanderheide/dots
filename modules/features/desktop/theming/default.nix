{
  inputs,
  ...
}:
{
  # Stylix's fonts and cursor, and noctalia's colors from the wallpaper: the
  # rules every target's template shares. Each target has a file of its own
  # here, with its template and settings.
  flake.nixosModules.theming =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.stylix.nixosModules.stylix
      ];

      config = {
        # Font rendering configuration
        fonts.fontconfig = {
          enable = true;
          antialias = true;

          hinting = {
            enable = true;
            style = "none";
          };

          subpixel = {
            lcdfilter = "none";
            rgba = "rgb";
          };
        };

        # Home-manager integration
        home-manager.sharedModules = [
          (
            { config, lib, ... }:
            {
              home.sessionVariables.XCURSOR_THEME = config.stylix.cursor.name;

              # Colors come from the current wallpaper instead of the fixed
              # base16 scheme (stylix.base16Scheme): noctalia generates a
              # Material You palette from it (same algorithm as matugen) and
              # renders it into the templates whenever the wallpaper changes.
              # Stylix keeps fonts, cursor and icons; its color output is
              # switched off for every app noctalia colors (in that app's
              # file), so the two don't both write the same files.
              stylix.targets.noctalia.colors.enable = false;

              # Stylix's noctalia image/wallpaper target fights with the
              # explicit wallpaper.default.path set in desktop-shell.nix,
              # which is the one source of truth for the actual wallpaper path.
              stylix.targets.noctalia.image.enable = false;

              # Home-manager rewrites dconf's gtk-theme (gtk.nix) and color-scheme
              # (stylix's polarity) on every activation, which would flip apps
              # back to dark while light mode is toggled on. Re-applying the
              # templates re-runs noctalia's gtk hook and color-scheme sync with
              # the current mode. Fails harmlessly when noctalia isn't running
              # yet (at boot it applies on startup).
              home.activation.noctaliaTemplatesApply =
                lib.hm.dag.entryAfter
                  [
                    "dconfSettings"
                    "noctaliaConfigReload"
                  ]
                  ''
                    run ${lib.getExe config.programs.noctalia.package} msg templates-apply || true
                  '';

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
                  # The Zed and Zen templates started in noctalia's community
                  # catalog, but are vendored rather than enabled as community
                  # templates: those are downloaded at runtime, and the Zen
                  # one's hook rewrites userChrome.css/user.js, which
                  # home-manager owns read-only. Zen's profile files (zen.nix)
                  # import the rendered CSS instead.
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

        stylix = {
          enable = true;
          autoEnable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
          polarity = "dark";

          cursor = {
            name = "Capitaine Cursors (Nord)";
            package = pkgs.capitaine-cursors-themed;
            size = 32;
          };

          fonts = {
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

            sizes = {
              applications = 11.5;
              desktop = 11.5;
              popups = 11.5;
              terminal = 11.5;
            };
          };
        };
      };
    };
}
