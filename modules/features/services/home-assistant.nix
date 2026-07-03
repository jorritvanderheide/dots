{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.home-assistant =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.home-assistant;
      subdomain = "home";
      port = 8123;

      hass-py = pkgs.home-assistant.python3Packages;
      enphase-envoy-installer = pkgs.buildHomeAssistantComponent rec {
        owner = "vincentwolsink";
        domain = "enphase_envoy";
        version = "0.8.4";
        src = pkgs.fetchFromGitHub {
          owner = "vincentwolsink";
          repo = "home_assistant_enphase_envoy_installer";
          tag = version;
          hash = "sha256-IHnJCtrAFhLoyyfgruvCIFFrtUTpTnebKWZcJA3ruog=";
        };
        dependencies = with hass-py; [
          pyjwt
          xmltodict
          httpx
          jsonpath
        ];
      };
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
            assertions = [
              {
                assertion = config.my.go2rtc.enable;
                message = "my.home-assistant requires my.go2rtc.enable: HA's go2rtc integration is configured to use the external instance at 127.0.0.1:1984.";
              }
            ];

            services.home-assistant = {
              enable = true;
              extraComponents = [
                "default_config"
                "esphome"
                "go2rtc"
                "reolink"
                "zha"
              ];
              customComponents = [ enphase-envoy-installer ];

              config = {
                default_config = { };
                go2rtc.url = "http://127.0.0.1:${toString config.my.go2rtc.apiPort}";
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

            # ZHA: let HA open the Zigbee dongle's serial port.
            users.users.hass.extraGroups = [ "dialout" ];

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
