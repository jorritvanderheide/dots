{
  flake.nixosModules.sound =
    {
      pkgs,
      ...
    }:
    {
      config = {
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
