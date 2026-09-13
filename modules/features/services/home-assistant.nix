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
      options.my.home-assistant = {
        enable = lib.mkEnableOption "Home Assistant smart home server";

        lanAccess = {
          enable = lib.mkEnableOption "plain-HTTP access from the home LAN, for devices with no Tailscale client";

          interface = lib.mkOption {
            type = lib.types.str;
            default = "enp2s0";
            description = "LAN interface to open the Home Assistant port on.";
          };
        };
      };

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
                "esphome"
                "reolink"
                "zha"
              ];
              customComponents = [ enphase-envoy-installer ];

              config = {
                default_config = { };
                homeassistant = {
                  latitude = 51.8425;
                  longitude = 5.8528;
                  elevation = 19;
                  unit_system = "metric";
                  time_zone = config.time.timeZone;
                };
                http = {
                  # Loopback is enough for the tailnet vhost, which proxies
                  # from 127.0.0.1. LAN access needs a real listener, and the
                  # firewall below is what keeps it to the LAN interface.
                  server_host = if cfg.lanAccess.enable then "0.0.0.0" else "127.0.0.1";
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

          # Scoped to the LAN interface rather than opened globally, which
          # would also expose it on the path the router forwards 443 in on.
          # Plain HTTP: this is the bare port, not the TLS vhost, so LAN
          # traffic here is unencrypted.
          (lib.mkIf cfg.lanAccess.enable {
            networking.firewall.interfaces.${cfg.lanAccess.interface}.allowedTCPPorts = [ port ];
          })
        ]
      );
    };
}
