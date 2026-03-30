{
  lib,
  ...
}:
{
  flake.nixosModules.sound =
    {
      config,
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = with pkgs; [
          pavucontrol
          playerctl
        ];

        # RealtimeKit for realtime priority
        security.rtkit.enable = true;

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;

          # LDAC 990kbps Bluetooth configuration
          wireplumber.configPackages = [
            (pkgs.writeTextDir "share/wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
              bluez_monitor.rules = {
                {
                  matches = {
                    {
                      { "device.name", "matches", "bluez_card.*" },
                    },
                  },
                  apply_properties = {
                    ["api.bluez5.codec-config.ldac.quality"] = "hq",
                    ["api.bluez5.codec-config.ldac.bitrate"] = 990000,
                  },
                },
              }
            '')
          ];
        };
      };
    };
}
