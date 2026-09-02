{
  flake.nixosModules.polkit =
    {
      config,
      pkgs,
      ...
    }:
    {
      config = {
        assertions = [
          {
            assertion = config.my.app-launch.enable or false;
            message = "my.polkit requires the app-launch module (provides the app2unit launcher).";
          }
        ];

        security.polkit.enable = true;

        environment.systemPackages = [
          pkgs.polkit_gnome
        ];

        home-manager.sharedModules = [
          {
            programs.niri.settings.spawn-at-startup = [
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
          }
        ];
      };
    };
}
