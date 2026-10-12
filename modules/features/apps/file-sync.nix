{
  lib,
  ...
}:
{
  flake.nixosModules.file-sync =
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
            message = "my.file-sync requires the app-launch module (provides the app2unit launcher).";
          }
        ];

        home-manager.sharedModules = [
          {
            home.packages = [ pkgs.nextcloud-client ];

            # In the tray from login; the account is set up once in its
            # wizard, with ~/Nextcloud as the folder, and its login kept in
            # the keyring.
            programs.niri.settings.spawn-at-startup = [
              {
                command = [
                  "app2unit"
                  "-s"
                  "a"
                  "--"
                  (lib.getExe' pkgs.nextcloud-client "nextcloud")
                  "--background"
                ];
              }
            ];
          }
        ];

        # Both, or a reboot leaves the client facing an empty folder where
        # its files were: the account and folder pairing, and the files.
        my.preservation.homeDirectories = [
          ".config/Nextcloud"
        ];
      };
    };
}
