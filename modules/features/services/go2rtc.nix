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
      webrtcPort = 8555;
    in
    {
      options.my.go2rtc = {
        enable = lib.mkEnableOption "go2rtc streaming server";

        apiPort = lib.mkOption {
          default = 1984;
          description = "Loopback port go2rtc's HTTP API listens on. Consumers (e.g. Home Assistant) read this instead of hardcoding.";
          readOnly = true;
          type = lib.types.port;
        };

        streams = lib.mkOption {
          default = { };
          description = "Streams definition for go2rtc.";
          type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
        };
      };

      config = lib.mkIf cfg.enable {
        services.go2rtc = {
          enable = true;

          settings = {
            api.listen = "127.0.0.1:${toString cfg.apiPort}";
            rtsp.listen = "127.0.0.1:8554";
            inherit (cfg) streams;
            webrtc.listen = ":${toString webrtcPort}";
          };
        };

        networking.firewall.interfaces."tailscale0" = {
          allowedTCPPorts = [ webrtcPort ];
          allowedUDPPorts = [ webrtcPort ];
        };
      };
    };
}
