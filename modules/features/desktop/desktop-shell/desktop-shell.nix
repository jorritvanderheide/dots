{
  inputs,
  ...
}:
{
  flake.nixosModules.desktop-shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.desktop-shell;

      quickshellPkg = inputs.quickshell.packages.${pkgs.system}.default; # Quickshell package

      # Theme.qml generated from the active Stylix base16 palette so shell
      # colors track the system theme.
      colors = config.lib.stylix.colors.withHashtag;
      themeQml = pkgs.writeText "Theme.qml" ''
        pragma Singleton

        import QtQuick

        QtObject {
            // Colors (from Stylix base16 palette)
            readonly property color backgroundColor: "${colors.base01}"
            readonly property color foregroundColor: "${colors.base05}"
            readonly property color accentColor: "${colors.base0D}"

            // Shared
            readonly property color panelBackground: backgroundColor

            // Dock
            readonly property int dockHeight: 64
            readonly property int dockIconSize: 48
            readonly property int dockSpacing: 8
            readonly property int dockPadding: 8
            readonly property int dockRadius: 16

            // Top bar
            readonly property int topBarHeight: 32
            readonly property int topBarPadding: 8
            readonly property int topBarSpacing: 16
            readonly property int topBarIconSize: 16
            readonly property int topBarSideMargin: 16

            // Typography
            readonly property int fontSizeSmall: 12
            readonly property int fontSizeNormal: 14
            readonly property int fontSizeLarge: 16
            readonly property int fontSizeIcon: 20

            // Spacing
            readonly property int spacingTiny: 4
            readonly property int spacingSmall: 8
            readonly property int spacingMedium: 16
            readonly property int spacingLarge: 24

            // Padding
            readonly property int paddingSmall: 8
            readonly property int paddingMedium: 16
            readonly property int paddingLarge: 24
        }
      '';

      # AppConfig.qml baked from the NixOS options. Generated here rather
      # than read via env vars so we don't have to worry about systemd's
      # Environment= quoting rules mangling JSON. Source-tree AppConfig.qml
      # stays as the env-var-driven fallback for dev launches.
      normalizedPinnedApps = map (
        p:
        if builtins.isString p then
          {
            id = p;
            aliases = [ ];
          }
        else
          p
      ) cfg.pinnedApps;
      appConfigQml = pkgs.writeText "AppConfig.qml" ''
        pragma Singleton

        import QtQuick

        QtObject {
            readonly property string monitor: ${builtins.toJSON cfg.monitor}
            readonly property var pinnedApps: ${builtins.toJSON normalizedPinnedApps}
        }
      '';

      qmlConfigPath = pkgs.runCommand "desktop-shell-qml" { } ''
        cp -r ${./qml} $out
        chmod -R u+w $out
        install -m 0644 ${themeQml} $out/common/Theme.qml
        install -m 0644 ${appConfigQml} $out/common/AppConfig.qml
      '';
    in
    {
      options.my.desktop-shell = {
        package = lib.mkOption {
          type = lib.types.package;
          default = quickshellPkg;
          description = "Quickshell package";
        };

        configPath = lib.mkOption {
          type = lib.types.path;
          default = qmlConfigPath;
          description = "Path to the QML configuration directory";
        };

        monitor = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "DP-1";
          description = ''
            Name of the monitor the dock should appear on (e.g. niri output name).
            When empty, the dock follows the focused output.
          '';
        };

        pinnedApps = lib.mkOption {
          type = lib.types.listOf (
            lib.types.either lib.types.str (
              lib.types.submodule {
                options = {
                  id = lib.mkOption {
                    type = lib.types.str;
                    description = "Pin identifier, matched against desktop entry id/name/StartupWMClass/exec-binary.";
                  };
                  aliases = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Additional app_ids (as niri reports them) that should match this pin.";
                  };
                };
              }
            )
          );
          default = [ ];
          example = [
            "zen-beta"
            "ghostty"
            {
              id = "signal";
              aliases = [ "electron" ];
            }
          ];
          description = ''
            App IDs pinned to the dock. Shown whether the app is running or not,
            in the order listed. Running windows of pinned apps appear in place
            of the static pin entry. Each entry is either a bare id string or an
            attribute set with `id` plus extra `aliases` for apps that report a
            different app_id than their desktop entry would imply (e.g. Electron
            apps reporting "electron").
          '';
        };
      };

      config = {
        environment.systemPackages = [
          cfg.package
          pkgs.kdePackages.qttools
        ];

        home-manager.sharedModules = [
          {
            home.sessionVariables = {
              QML2_IMPORT_PATH = lib.concatStringsSep ":" [
                (lib.makeSearchPath "lib/qt-6/qml" [
                  cfg.package
                  pkgs.kdePackages.kirigami.unwrapped
                  pkgs.kdePackages.qt5compat
                  pkgs.kdePackages.qtdeclarative
                ])
              ];
            };

            # Run quickshell as a systemd user unit so `home-manager switch`
            # (invoked by nixos-rebuild) restarts it whenever the unit's text
            # changes: the package, the QML config derivation, or any of the
            # Environment values below (pinned apps, monitor, etc.). Tied to
            # graphical-session.target so it starts with the compositor session
            # and stops when the session ends.
            systemd.user.services.quickshell = {
              Install.WantedBy = [ "graphical-session.target" ];

              Service = {
                ExecStart = "${lib.getExe cfg.package} -c ${cfg.configPath}";
                Environment = [ "QS_NO_RELOAD_POPUP=1" ];
                Restart = "on-failure";
                RestartSec = 2;
              };

              Unit = {
                Description = "Quickshell desktop shell";
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
              };
            };
          }
        ];
      };
    };
}
