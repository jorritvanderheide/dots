{
  lib,
  ...
}:
{
  flake.nixosModules.polkit =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.polkit;
    in
    {
      options.settings.polkit = {
        enable = lib.mkEnableOption "polkit authentication agent";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: app-launch must be enabled for app2unit command
        assertions = [
          {
            assertion = config.settings.compositor.enable or false;
            message = "settings.polkit requires settings.compositor to be enabled (for niri spawn-at-startup)";
          }
          {
            assertion = config.settings.app-launch.enable or false;
            message = "settings.polkit requires settings.app-launch to be enabled (for app2unit)";
          }
        ];

        security.polkit.enable = true;
        environment.systemPackages = [ pkgs.polkit_gnome ];

        home-manager.sharedModules = [
          {
            programs.niri = {
              enable = true;
              settings = {
                spawn-at-startup = [
                  {
                    command = [
                      "app2unit"
                      "-s"
                      "b"
                      "--"
                      "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
                    ];
                  }
                ];
              };
            };
          }
        ];
      };
    };
}
