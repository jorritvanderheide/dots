{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.home-assistant =
    {
      config,
      ...
    }:
    let
      cfg = config.my.home-assistant;
      subdomain = "home";
      port = 8123;
    in
    {
      options.my.home-assistant.enable = lib.mkEnableOption "Home Assistant smart home server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;
          })
          {
            services.home-assistant = {
              enable = true;
              extraComponents = [
                "default_config"
                "enphase_envoy"
                "esphome"
                "go2rtc"
              ];

              config = {
                default_config = { };
                go2rtc.url = "http://127.0.0.1:1984";
                homeassistant = {
                  latitude = 51.8425;
                  longitude = 5.8528;
                  elevation = 19;
                  unit_system = "metric";
                  time_zone = config.time.timeZone;
                };
                http = {
                  server_host = "127.0.0.1";
                  server_port = port;
                  use_x_forwarded_for = true;
                  trusted_proxies = [ "127.0.0.1" ];
                };
              };
            };

            systemd.services.home-assistant.serviceConfig.Restart = lib.mkForce "always";

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/hass";
                user = "hass";
                group = "hass";
                mode = "0700";
              }
            ];
          }
        ]
      );
    };
}
