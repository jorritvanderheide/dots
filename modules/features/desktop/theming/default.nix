{
  inputs,
  ...
}:
{
  flake.nixosModules.theming =
    {
      config,
      pkgs,
      ...
    }:
    let
      # Only set on hosts that import the research module (Obsidian vault).
      # Resolved out here because the home-manager module below rebinds
      # `config`.
      vaultPath = config.my.research.vaultPath or null;
    in
    {
      imports = [
        inputs.stylix.nixosModules.stylix
      ];

      config = {
        # The NixOS-level counterpart of the home-manager fish target
        # disabled below: it sources base16-fish from /etc/fish/config.fish,
        # which overwrites the terminal palette with Dracula via escape
        # sequences and pins Dracula hex colors in fish's universal variables.
        stylix.targets.fish.colors.enable = false;

        # Qt is themed from noctalia's qtct palette below instead. Stylix's
        # Qt target forces the Kvantum style, which ignores qtct palettes.
        stylix.targets.qt.enable = false;

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
            let
              # Numix's folder icons are fixed colors, so a separate theme on
              # top of Numix-Circle carries recolored ones. This is its
              # skeleton: Numix's custom folder set, whose colors are
              # placeholders, under every name that resolves to the default
              # (orange) set.
              numixFolders = pkgs.runCommand "numix-folders" { } ''
                cd ${pkgs.numix-icon-theme}/share/icons/Numix
                mkdir $out
                sed -e 's/^Name=.*/Name=Numix Circle Noctalia/' -e 's/^Inherits=.*/Inherits=Numix-Circle/' \
                  index.theme > $out/index.theme
                for size in 16 22 24 32 48 64; do
                  ln -s $size $out/$size@2x
                done
                folders() {
                  find 16 22 24 32 48 64 "$@" \( -path '*/places/*' -o -path '*/actions/*' \)
                }
                folders -type f -name 'custom-*' -exec cp --parents --no-preserve=mode -t $out {} +
                # Resolved in one batch: one realpath per link takes minutes.
                folders -type l > $TMPDIR/links
                xargs -a $TMPDIR/links -d '\n' realpath --relative-to=. > $TMPDIR/targets
                paste -d ' ' $TMPDIR/links $TMPDIR/targets | while read -r link target; do
                  # target: <size>/<context>/<file>, the context kept for the link
                  context=''${target#*/}
                  case ''${target##*/} in
                    default-*) ln -s ../''${context/default-/custom-} $out/$link ;;
                  esac
                done
              '';

              # Recolors a fresh copy of the skeleton and swaps it in: a new
              # theme directory is also what makes running GTK apps reload
              # their icons.
              numixFoldersApply = pkgs.writeShellApplication {
                name = "numix-folders-apply";

                runtimeInputs = with pkgs; [
                  coreutils
                  findutils
                  gnused
                ];

                text = ''
                  theme=${config.xdg.dataHome}/icons/Numix-Circle-Noctalia
                  mkdir -p ${config.xdg.dataHome}/icons
                  new=$(mktemp -d "$theme.XXXXXX")
                  cp -rT --no-preserve=mode ${numixFolders} "$new"
                  find "$new" -type f -name '*.svg' -exec sed -i -f "$1" {} +
                  chmod 755 "$new"
                  rm -rf "$theme.old"
                  if [[ -e $theme ]]; then mv "$theme" "$theme.old"; fi
                  mv "$new" "$theme"
                  rm -rf "$theme.old"
                '';
              };
            in
            {
              home.sessionVariables.XCURSOR_THEME = config.stylix.cursor.name;
              programs.bat.config.theme = "ansi";

              # Only the 16 ANSI colors; fzf's default scheme also uses fixed
              # xterm-256 greys that no theme controls.
              programs.fzf.defaultOptions = [ "--color=16" ];

              programs.ghostty.settings.theme = "noctalia-terminal";

              # Stylix's noctalia image/wallpaper target fights with the
              # explicit wallpaper.default.path set in desktop-shell.nix,
              # which is the one source of truth for the actual wallpaper path.
              stylix.targets.noctalia.image.enable = false;

              gtk.theme = {
                # Only the initial value: noctalia's gtk hook switches dconf's
                # gtk-theme between adw-gtk3 and adw-gtk3-dark with the mode.
                name = "adw-gtk3-dark";

                package = pkgs.adw-gtk3;
              };

              # Home-manager rewrites dconf's gtk-theme (above) and color-scheme
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
                  # All templates below share one set of rules: chrome
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
                  # home-manager owns read-only. The profile files below
                  # import the rendered CSS instead.
                  enable_community_templates = false;

                  # Ghostty and Qt use own templates instead (below).
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

                  user =
                    lib.optionalAttrs (vaultPath != null) {
                      obsidian = {
                        input_path = "${./noctalia-templates/obsidian-border.css}";
                        output_path = "${config.home.homeDirectory}/${vaultPath}/.obsidian/snippets/noctalia.css";
                      };
                    }
                    // {
                      eza = {
                        input_path = "${./noctalia-templates/eza-theme.yml}";
                        output_path = "${config.xdg.configHome}/eza/theme.yml";
                      };

                      # Own template instead of the built-in one, whose ANSI
                      # colors come from the wallpaper (magenta == green, ...).
                      # Different theme name: switching the built-in off runs its
                      # undo hook, which deletes themes/noctalia.
                      ghostty = {
                        input_path = "${./noctalia-templates/ghostty}";
                        output_path = "${config.xdg.configHome}/ghostty/themes/noctalia-terminal";
                        post_hook = "bash ${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty/reload.sh";
                      };

                      # Imported after the built-in template's noctalia.css by
                      # gtk.css (below), so these definitions win.
                      gtk3_overrides = {
                        input_path = "${./noctalia-templates/gtk3-overrides.css}";
                        output_path = "${config.xdg.configHome}/gtk-3.0/noctalia-overrides.css";
                      };

                      gtk4_overrides = {
                        input_path = "${./noctalia-templates/gtk4-overrides.css}";
                        output_path = "${config.xdg.configHome}/gtk-4.0/noctalia-overrides.css";
                      };

                      numix_folders = {
                        input_path = "${./noctalia-templates/numix-folders.sed}";
                        output_path = "${config.xdg.cacheHome}/noctalia/numix-folders.sed";
                        post_hook = "${lib.getExe numixFoldersApply} ${config.xdg.cacheHome}/noctalia/numix-folders.sed";
                      };

                      # Different file name: switching the built-in Qt template
                      # off runs its undo hook, which deletes colors/noctalia.conf.
                      qt = {
                        input_path = "${./noctalia-templates/qtct.conf}";

                        output_path = [
                          "${config.xdg.configHome}/qt5ct/colors/noctalia-qt.conf"
                          "${config.xdg.configHome}/qt6ct/colors/noctalia-qt.conf"
                        ];
                      };

                      zed = {
                        input_path = "${./noctalia-templates/zed.json}";
                        output_path = "${config.xdg.configHome}/zed/themes/noctalia.json";
                      };

                    };
                };
              };

              programs.zed-editor.userSettings.theme = {
                dark = "Noctalia Dark";
                light = "Noctalia Light";
                mode = "system";
              };

              # Same qtct settings stylix's Qt target wrote, minus Kvantum:
              # Fusion draws with the qtct palette, so the noctalia colors
              # actually show.
              qt = {
                enable = true;
                platformTheme.name = "qtct";
              }
              // lib.genAttrs [ "qt5ctSettings" "qt6ctSettings" ] (
                name:
                let
                  qtct = lib.removeSuffix "Settings" name;
                in
                {
                  Appearance = {
                    color_scheme_path = "${config.xdg.configHome}/${qtct}/colors/noctalia-qt.conf";
                    custom_palette = true;
                    icon_theme = config.stylix.icons.dark;
                    standard_dialogs = "default";
                    style = "Fusion";
                  };

                  Fonts = with config.stylix.fonts; {
                    fixed = ''"${monospace.name},${toString sizes.applications}"'';
                    general = ''"${sansSerif.name},${toString sizes.applications}"'';
                  };
                }
              );

              stylix.icons = {
                enable = true;

                # Numix-Circle with the folders in the wallpaper's colors
                # (numixFolders above). Only dark is used: stylix's polarity
                # stays dark, and noctalia doesn't switch icon themes.
                dark = "Numix-Circle-Noctalia";
                light = "Numix-Circle-Light";
                package = pkgs.numix-icon-theme-circle;
              };

              # Colors come from the current wallpaper instead of the fixed
              # base16 scheme (stylix.base16Scheme): noctalia generates a Material You palette
              # from it (same algorithm as matugen) and renders it into the
              # templates whenever the wallpaper changes. Stylix keeps
              # fonts, cursor and icons; its color output is switched off for
              # every app noctalia now colors, so the two don't both write
              # the same files.
              stylix.targets = {
                # These use the terminal's ANSI colors instead,
                # so they follow the same palette as Ghostty. Stylix's
                # hard-coded Dracula hex values made bat's text near-white,
                # unreadable on a light terminal.
                bat.colors.enable = false;
                fzf.colors.enable = false;
                starship.colors.enable = false;
                tmux.colors.enable = false;

                # base16-fish rewrites the terminal palette with escape
                # sequences on every shell start, which would override the
                # Ghostty theme noctalia writes.
                fish.colors.enable = false;

                ghostty.colors.enable = false;
                gtk.colors.enable = false;
                noctalia.colors.enable = false;
                qt.enable = false;
                zed.colors.enable = false;
                zen-browser.colors.enable = false;
              };

              # Written directly rather than via gtk.gtk{3,4}.extraCss, which
              # stylix warns about even with its gtk colors disabled. The
              # built-in gtk hook only checks that noctalia.css is imported.
              xdg.configFile =
                lib.genAttrs [ "gtk-3.0/gtk.css" "gtk-4.0/gtk.css" ] (_: {
                  text = ''
                    @import url("noctalia.css");
                    @import url("noctalia-overrides.css");
                  '';
                })
                // {
                  # home-manager validates ghostty's config whenever it changed,
                  # which at boot is always (the home folder starts empty), and
                  # that's before noctalia has written its theme: validate once
                  # the theme exists.
                  "ghostty/config".onChange = lib.mkForce ''
                    if [[ -e ${config.xdg.configHome}/ghostty/themes/noctalia-terminal ]]; then
                      ${lib.getExe config.programs.ghostty.package} +validate-config --config-file=${config.xdg.configHome}/ghostty/config
                    fi
                  '';
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
