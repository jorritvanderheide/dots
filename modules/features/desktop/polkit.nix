{
  flake.nixosModules.polkit =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Assertion: app-launch must be enabled for app2unit command
        security.polkit.enable = true;
        environment.systemPackages = [ pkgs.polkit_gnome ];

        home-manager.sharedModules = [
          {
            programs.niri = {
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
