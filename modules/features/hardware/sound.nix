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
    let
      cfg = config.settings.sound;
    in
    {
      options.settings.sound = {
        enable = lib.mkEnableOption "sound management";
      };

      config = lib.mkIf cfg.enable {
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
        };
      };
    };
}
