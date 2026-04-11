{
  ...
}:
{
  flake.nixosModules.via =
    {
      pkgs,
      ...
    }:
    {
      # Persist VIA configuration
      my.preservation.homeDirectories = [
        ".config/chromium"
      ];

      # VIA web app launched in Chromium (WebHID support)
      home-manager.sharedModules = [
        {
          home.packages = [
            pkgs.chromium
            (pkgs.makeDesktopItem {
              name = "via";
              desktopName = "VIA";
              comment = "Keyboard configurator";
              exec = "${pkgs.chromium}/bin/chromium --app=https://usevia.app";
              icon = "input-keyboard";
              categories = [ "Utility" "Settings" ];
            })
          ];
        }
      ];

      # udev rules for raw HID access (required for VIA to communicate with keyboards)
      services.udev.packages = [ pkgs.via ];
    };
}
