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
        stylix = {
          enable = true;
          autoEnable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
          polarity = "dark";

          cursor = {
            package = pkgs.capitaine-cursors-themed;
            name = "Capitaine Cursors (Nord)";
            size = 32;
          };

          fonts = {
            emoji = {
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };

            monospace = {
              package = pkgs.nerd-fonts.jetbrains-mono;
              name = "JetBrainsMono Nerd Font Mono";
            };

            sansSerif = {
              package = pkgs.rubik;
              name = "Rubik";
            };

            serif = {
              package = pkgs.dejavu_fonts;
              name = "DejaVu Serif";
            };

            sizes = {
              applications = 11.5;
              desktop = 11.5;
              popups = 11.5;
              terminal = 11.5;
            };
          };
        };

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

        # Qt is themed from noctalia's qtct palette below instead. Stylix's
        # Qt target forces the Kvantum style, which ignores qtct palettes.
        stylix.targets.qt.enable = false;

        # The NixOS-level counterpart of the home-manager fish target
        # disabled below: it sources base16-fish from /etc/fish/config.fish,
        # which overwrites the terminal palette with Dracula via escape
        # sequences and pins Dracula hex colors in fish's universal variables.
        stylix.targets.fish.colors.enable = false;

        # Home-manager integration
        home-manager.sharedModules = [
          (
            { config, lib, ... }:
            {
              home.sessionVariables.XCURSOR_THEME = config.stylix.cursor.name;
              # Stylix's noctalia image/wallpaper target fights with the
              # explicit wallpaper.default.path set in desktop-shell.nix,
              # which is the one source of truth for the actual wallpaper path.
              stylix.targets.noctalia.image.enable = false;

              stylix.icons = {
                enable = true;
                dark = "Numix-Circle";
                light = "Numix-Circle-Light";
                package = pkgs.numix-icon-theme-circle;
              };

              # Colors come from the current wallpaper instead of the fixed
              # base16 scheme above: noctalia generates a Material You palette
              # from it (same algorithm as matugen) and renders it into the
              # templates below whenever the wallpaper changes. Stylix keeps
              # fonts, cursor and icons; its color output is switched off for
              # every app noctalia now colors, so the two don't both write
              # the same files.
              stylix.targets = {
                ghostty.colors.enable = false;
                gtk.colors.enable = false;
                noctalia.colors.enable = false;
                qt.enable = false;
                zed.colors.enable = false;
                zen-browser.colors.enable = false;
                # base16-fish rewrites the terminal palette with escape
                # sequences on every shell start, which would override the
                # Ghostty theme noctalia writes.
                fish.colors.enable = false;
                # These three use the terminal's ANSI colors instead (below),
                # so they follow the same palette as Ghostty. Stylix's
                # hard-coded Dracula hex values made bat's text near-white,
                # unreadable on a light terminal.
                bat.colors.enable = false;
                fzf.colors.enable = false;
                tmux.colors.enable = false;
              };

              programs.bat.config.theme = "ansi";
              # Only the 16 ANSI colors; fzf's default scheme also uses fixed
              # xterm-256 greys that no theme controls.
              programs.fzf.defaultOptions = [ "--color=16" ];

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
                    red = {
                      color = "#e05561";
                      blend = false;
                    };
                    orange = {
                      color = "#d9773c";
                      blend = false;
                    };
                    yellow = {
                      color = "#d9b63c";
                      blend = false;
                    };
                    green = {
                      color = "#5fae5a";
                      blend = false;
                    };
                    cyan = {
                      color = "#3fb0b8";
                      blend = false;
                    };
                    blue = {
                      color = "#5a7fe6";
                      blend = true;
                    };
                    purple = {
                      color = "#b86bd9";
                      blend = true;
                    };
                  };

                  # All templates below share one set of rules: chrome
                  # (panels, sidebars, toolbars, bars) on the wallpaper's
                  # middle surface tone; content (editor, terminal, notes,
                  # pages, lists) one step further out (lightest in light mode,
                  # darker in dark mode); meaning (errors, git, ANSI, syntax)
                  # from custom_colors above; accent used as text darkened in
                  # light mode. Each template file explains its specifics.
                  #
                  # Origin of the files in ./noctalia-templates:
                  # - zed.json, zen-userChrome.css, zen-userContent.css:
                  #   noctalia's community catalog
                  #   (https://api.noctalia.dev/templates/{zed,zen-browser}),
                  #   copied 2026-10-07 and since reworked: semantic colors,
                  #   content/chrome tones, light-mode accent text (Zed); the
                  #   Zen color variables moved into zen-colors.css. Vendored
                  #   rather than enabled as community templates, which are
                  #   downloaded at runtime and whose Zen hook rewrites
                  #   userChrome.css/user.js, which home-manager owns
                  #   read-only; the profile files below import the rendered
                  #   CSS instead.
                  # - ghostty, qtct.conf: own, replacing noctalia's built-in
                  #   Ghostty and Qt templates (noctalia 5.2.1).
                  # - fish.fish: own, prompt accent only.
                  # - eza-theme.yml: own, directory accent only.
                  # - gtk3-overrides.css, gtk4-overrides.css: own, layered on
                  #   top of the built-in GTK templates, which stay enabled.
                  # - obsidian-border.css: own, for the Border theme, which is
                  #   recolored through Style Settings (see the file). Switched
                  #   on once by hand in Settings > Appearance > CSS snippets.
                  enable_community_templates = false;

                  user =
                    lib.optionalAttrs (vaultPath != null) {
                      obsidian = {
                        input_path = "${./noctalia-templates/obsidian-border.css}";
                        output_path = "${config.home.homeDirectory}/${vaultPath}/.obsidian/snippets/noctalia.css";
                      };
                    }
                    // {
                      # Own template instead of the built-in one, whose ANSI
                      # colors come from the wallpaper (magenta == green, ...).
                      # Different theme name: switching the built-in off runs its
                      # undo hook, which deletes themes/noctalia.
                      ghostty = {
                        input_path = "${./noctalia-templates/ghostty}";
                        output_path = "${config.xdg.configHome}/ghostty/themes/noctalia-terminal";
                        post_hook = "bash ${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty/reload.sh";
                      };

                      fish = {
                        input_path = "${./noctalia-templates/fish.fish}";
                        output_path = "${config.xdg.cacheHome}/noctalia/fish-colors.fish";
                        post_hook = "${lib.getExe config.programs.fish.package} ${config.xdg.cacheHome}/noctalia/fish-colors.fish";
                      };

                      eza = {
                        input_path = "${./noctalia-templates/eza-theme.yml}";
                        output_path = "${config.xdg.configHome}/eza/theme.yml";
                      };

                      zed = {
                        input_path = "${./noctalia-templates/zed.json}";
                        output_path = "${config.xdg.configHome}/zed/themes/noctalia.json";
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

                      # Different file name: switching the built-in Qt template
                      # off runs its undo hook, which deletes colors/noctalia.conf.
                      qt = {
                        input_path = "${./noctalia-templates/qtct.conf}";
                        output_path = [
                          "${config.xdg.configHome}/qt5ct/colors/noctalia-qt.conf"
                          "${config.xdg.configHome}/qt6ct/colors/noctalia-qt.conf"
                        ];
                      };

                      zen_colors = {
                        input_path = "${./noctalia-templates/zen-colors.css}";
                        output_path = "${config.xdg.cacheHome}/noctalia/zen-browser/zen-colors.css";
                      };

                      zen_browser_chrome = {
                        input_path = "${./noctalia-templates/zen-userChrome.css}";
                        output_path = "${config.xdg.cacheHome}/noctalia/zen-browser/zen-userChrome.css";
                      };

                      zen_browser_content = {
                        input_path = "${./noctalia-templates/zen-userContent.css}";
                        output_path = "${config.xdg.cacheHome}/noctalia/zen-browser/zen-userContent.css";
                      };
                    };
                };
              };

              programs.ghostty.settings.theme = "noctalia-terminal";

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

              gtk.theme = {
                package = pkgs.adw-gtk3;
                # Only the initial value: noctalia's gtk hook switches dconf's
                # gtk-theme between adw-gtk3 and adw-gtk3-dark with the mode.
                name = "adw-gtk3-dark";
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

              programs.zed-editor.userSettings.theme = {
                mode = "system";
                light = "Noctalia Light";
                dark = "Noctalia Dark";
              };

              programs.zen-browser.profiles."default" = {
                # 2 = follow the system color-scheme (stylix pins 0, dark).
                # The imported CSS carries both variants under
                # prefers-color-scheme.
                settings."zen.view.window.scheme" = lib.mkForce 2;

                # Colors come from zen-colors.css, loaded by the autoconfig below.
                userChrome = ''@import url("file://${config.xdg.cacheHome}/noctalia/zen-browser/zen-userChrome.css");'';
                userContent = ''@import url("file://${config.xdg.cacheHome}/noctalia/zen-browser/zen-userContent.css");'';
              };

              # Firefox only reads userChrome/userContent at startup, so colors
              # imported there would stay stale after a wallpaper or light/dark
              # change. Zen's autoconfig (noctalia.cfg, privileged JS run at
              # startup) instead registers zen-colors.css as a user stylesheet,
              # checks its timestamp every second, and swaps in the new version
              # once noctalia has finished rewriting it; the stylesheet service
              # applies that to open windows immediately.
              #
              # Installed into the unwrapped package, not via the module's
              # extraPrefs: wrapFirefox writes mozilla.cfg next to its own copy
              # of the binary, but Zen's binary keeps its unwrapped name, so the
              # wrapper only symlinks it and Gecko reads mozilla.cfg next to the
              # resolved /proc/self/exe, i.e. the unwrapped package. (The zen
              # module bakes its policies into the unwrapped package for the same
              # reason; the override below keeps doing that.)
              # Named noctalia.cfg/noctalia-autoconfig.js because the wrapper
              # writes its own (unused) mozilla.cfg/autoconfig.js next to the
              # symlinks it makes to these files.
              programs.zen-browser.unwrappedPackage =
                let
                  zen = config.programs.zen-browser;
                  autoconfigPrefs = pkgs.writeText "noctalia-autoconfig.js" ''
                    pref("general.config.filename", "noctalia.cfg");
                    pref("general.config.obscure_value", 0);
                    // Off, like the zen flake's Sine loader does: in the sandbox the script
                    // has no Cc/Ci and cannot reach the stylesheet service.
                    pref("general.config.sandbox_enabled", false);
                  '';
                  autoconfig = pkgs.writeText "noctalia.cfg" ''
                    // First line must be a comment.
                    // noctalia live colors (theming.nix)
                    // Never throws: an uncaught error here makes Firefox show an error
                    // dialog at startup.
                    const log = (e) => { try { console.error("noctalia live colors:", e); } catch (_) {} };
                    try {
                      const path = "${config.xdg.cacheHome}/noctalia/zen-browser/zen-colors.css";
                      const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
                      const ios = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
                      let sheet = null;
                      let applied = 0;
                      let seen = 0;
                      const mtime = () => {
                        const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
                        file.initWithPath(path);
                        return file.exists() ? file.lastModifiedTime : 0;
                      };
                      const apply = (stamp) => {
                        // The query makes each version a new URI, so the sheet
                        // cache can't hand back the old one.
                        const next = ios.newURI("file://" + path + "?" + stamp);
                        sss.loadAndRegisterSheet(next, sss.USER_SHEET);
                        if (sheet) sss.unregisterSheet(sheet, sss.USER_SHEET);
                        sheet = next;
                        applied = stamp;
                      };
                      const poll = () => {
                        try {
                          const stamp = mtime();
                          // Apply only once the timestamp held for a whole tick,
                          // so a file still being written isn't loaded half-done.
                          if (stamp !== seen) { seen = stamp; return; }
                          if (stamp && stamp !== applied) apply(stamp);
                        } catch (e) {
                          log(e);
                        }
                      };
                      seen = mtime();
                      if (seen) apply(seen);
                      const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
                      timer.initWithCallback({ notify: poll }, 1000, Ci.nsITimer.TYPE_REPEATING_SLACK);
                      // The observer service holds this observer strongly, which
                      // keeps the timer referenced (and so running) until quit.
                      Cc["@mozilla.org/observer-service;1"].getService(Ci.nsIObserverService)
                        .addObserver({ observe: () => timer.cancel() }, "quit-application");
                    } catch (e) {
                      log(e);
                    }
                  '';
                in
                (inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.override {
                  inherit (zen) policies enablePrivateDesktopEntry;
                }).overrideAttrs
                  (old: {
                    postInstall = (old.postInstall or "") + ''
                      for libdir in "$out"/lib/zen-bin-*; do
                        chmod -R u+w "$libdir/defaults"
                        install -m 644 ${autoconfig} "$libdir/noctalia.cfg"
                        install -D -m 644 ${autoconfigPrefs} "$libdir/defaults/pref/noctalia-autoconfig.js"
                      done
                    '';
                  });

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
            }
          )
        ];
      };
    };
}
