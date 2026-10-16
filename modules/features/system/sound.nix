{
  flake.nixosModules.sound =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Each device's profile and volume. Without it, a Bluetooth headset
        # can come back on the call profile after a boot instead of A2DP.
        my.preservation.homeDirectories = [ ".local/state/wireplumber" ];

        security.rtkit.enable = true;

        environment.systemPackages = with pkgs; [
          pavucontrol
        ];

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;

          # LDAC at its highest bitrate (990 kbps), not the adaptive one.
          wireplumber.extraConfig."51-bluez-ldac"."monitor.bluez.rules" = [
            {
              actions.update-props."bluez5.a2dp.ldac.quality" = "hq";
              matches = [ { "device.name" = "~bluez_card.*"; } ];
            }
          ];
        };
      };
    };
}
