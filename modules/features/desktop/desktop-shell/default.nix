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
      cfg = config.settings.desktop-shell;

      quickshellPkg = inputs.quickshell.packages.${pkgs.system}.default; # Quickshell package
      qmlConfigPath = inputs.self + "/modules/features/desktop/desktop-shell/qml"; # Path to QML configuration files
    in
    {
      options.settings.desktop-shell = {
        enable = lib.mkEnableOption "the desktop shell";

        package = lib.mkOption {
          type = lib.types.package;
          default = quickshellPkg;
          description = "Quickshell package to use";
        };

        configPath = lib.mkOption {
          type = lib.types.path;
          default = qmlConfigPath;
          description = "Path to QML configuration directory";
        };
      };

      config = lib.mkIf cfg.enable {
        # Assertion: compositor must be enabled
        assertions = [
          {
            assertion = config.settings.compositor.enable or false;
            message = "settings.desktop-shell requires settings.compositor to be enabled";
          }
        ];

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
            # programs.niri.settings.spawn-at-startup = lib.mkIf (config.settings.compositor.name == "niri") [
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
