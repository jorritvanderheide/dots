{ inputs, ... }:
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
      qmlConfigPath = inputs.self + "/modules/features/desktop/desktop-shell/qml"; # Path to QML configuration files
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

            # Launch quickshell via compositor
            # programs.niri.settings.spawn-at-startup = lib.mkIf (config.my.compositor.name == "niri") [
            #   {
            #     command = [
            #       "app2unit"
            #       "-s"
            #       "a"
            #       "--"
            #       "${lib.getExe cfg.package}"
            #       "-c"
            #       "${cfg.configPath}"
            #     ];
            #   }
            # ];
          }
        ];
      };
    };
}
