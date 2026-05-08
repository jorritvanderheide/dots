{
  lib,
  ...
}:
{
  flake.nixosModules.go2rtc =
    {
      config,
      ...
    }:
    let
      cfg = config.my.go2rtc;
      apiPort = 1984;
      webrtcPort = 8555;
    in
    {
      options.my.go2rtc = {
        enable = lib.mkEnableOption "go2rtc streaming server";

        streams = lib.mkOption {
          type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
          default = { };
          description = "Streams definition for go2rtc.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.go2rtc = {
          enable = true;
          settings = {
            api.listen = "127.0.0.1:${toString apiPort}";
            rtsp.listen = "127.0.0.1:8554";
            webrtc.listen = ":${toString webrtcPort}";
            streams = cfg.streams;
          };
        };

        networking.firewall.interfaces."tailscale0" = {
          allowedTCPPorts = [ webrtcPort ];
          allowedUDPPorts = [ webrtcPort ];
        };
      };
    };
}
