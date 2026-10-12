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
        domain = "enphase_envoy";
        owner = "vincentwolsink";
        version = "0.8.4";

        dependencies = with hass-py; [
          pyjwt
          xmltodict
          httpx
          jsonpath
        ];

        src = pkgs.fetchFromGitHub {
          hash = "sha256-IHnJCtrAFhLoyyfgruvCIFFrtUTpTnebKWZcJA3ruog=";
          owner = "vincentwolsink";
          repo = "home_assistant_enphase_envoy_installer";
          tag = version;
        };
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
            # ZHA: let HA open the Zigbee dongle's serial port.
            users.users.hass.extraGroups = [ "dialout" ];

            my.offsite-backup.entries.home-assistant = {
              paths = [ "/var/lib/hass" ];
              units = [ "home-assistant.service" ];
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/hass";
                group = "hass";
                mode = "0700";
                user = "hass";
              }
            ];

            services.home-assistant = {
              enable = true;

              config = {
                # Automations made in the UI live in automations.yaml, next
                # to the declared ones (automations.nix).
                "automation ui" = "!include automations.yaml";

                default_config = { };

                homeassistant = {
                  # The home's location: from secrets.yaml (below), as this
                  # repository is public.
                  elevation = "!secret elevation";
                  latitude = "!secret latitude";
                  longitude = "!secret longitude";

                  time_zone = config.time.timeZone;
                  unit_system = "metric";
                };

                http = {
                  # Ban an address after 5 failed logins (HA's default never does).
                  ip_ban_enabled = true;
                  login_attempts_threshold = 5;

                  # Loopback is enough for the tailnet vhost, which proxies
                  # from 127.0.0.1. LAN access needs a real listener, and the
                  # firewall below is what keeps it to the LAN interface.
                  server_host = if cfg.lanAccess.enable then "0.0.0.0" else "127.0.0.1";

                  server_port = port;
                  trusted_proxies = [ "127.0.0.1" ];
                  use_x_forwarded_for = true;
                };

              };

              customComponents = [
                enphase-envoy-installer
                pkgs.home-assistant-custom-components.localtuya
              ];

              extraComponents = [
                "default_config"
                "esphome"
                "reolink"
                "zha"
              ];
            };

            systemd.services.home-assistant = {
              after = [ "home-assistant-secrets.service" ];
              wants = [ "home-assistant-secrets.service" ];
            };

            # What the configuration takes with !secret, from sops: a YAML
            # document under home_assistant_secrets.
            systemd.services.home-assistant-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt Home Assistant's secrets.yaml from sops";
              extraServiceConfig.UMask = "0177";
              wantedBy = [ "multi-user.target" ];

              script = ''
                sops_extract home_assistant_secrets > ${config.services.home-assistant.configDir}/secrets.yaml
                chown hass:hass ${config.services.home-assistant.configDir}/secrets.yaml
              '';
            };

            systemd.services.home-assistant.serviceConfig = {
              # Upstream grants these for default_config's DHCP sniffing and
              # raw Bluetooth, neither of which this needs. With them, a
              # compromised integration could rewrite the firewall or sniff
              # the host's traffic. Bluetooth over BlueZ's D-Bus still works.
              AmbientCapabilities = lib.mkForce [ "" ];
              CapabilityBoundingSet = lib.mkForce [ "" ];

              Restart = lib.mkForce "always";
            };

            # The include above stops HA from starting if the file is
            # missing. "f" only creates it; existing content is left alone.
            systemd.tmpfiles.rules = [
              "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass - []"
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
