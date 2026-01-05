{
  lib,
  ...
}:
{
  flake.nixosModules.networking =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.features.networking;
    in
    {
      options.features.networking = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable custom networking configuration";
        };

        DOHServers = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          description = "DNS over HTTPS servers to use";
          default = null;
        };

        hosts = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          description = "Mapping of IP → list of hostnames";
          example = {
            "192.168.1.1" = [ "hostname" ];
          };
        };

        staticConfig = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                address = lib.mkOption {
                  type = lib.types.str;
                  description = "Static IP address";
                };

                interface = lib.mkOption {
                  type = lib.types.str;
                  description = "Network interface name";
                };

                gateway = lib.mkOption {
                  type = lib.types.str;
                  description = "Default gateway address";
                };
              };
            }
          );
          default = null;
          description = "Static network configuration. If null, DHCP will be used.";
        };

        wireless = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                interface = lib.mkOption {
                  type = lib.types.str;
                  description = "Wireless interface name";
                };

                networks = lib.mkOption {
                  type = lib.types.attrsOf (
                    lib.types.submodule {
                      options = {
                        priority = lib.mkOption {
                          type = lib.types.int;
                          default = 5;
                          description = "Network priority (higher = preferred)";
                        };

                        psk = lib.mkOption {
                          type = lib.types.str;
                          description = "Pre-shared key (password)";
                        };
                      };
                    }
                  );
                  default = { };
                  description = "Wireless networks to configure";
                };
              };
            }
          );
          default = null;
          description = "Wireless configuration. If null, wireless will be disabled.";
        };

        firewallPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          description = "TCP ports to allow through the firewall";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.networking requires features.impermanence to be enabled";
          }
          {
            assertion =
              (cfg.wireless != null && cfg.staticConfig != null)
              -> cfg.wireless.interface == cfg.staticConfig.interface;
            message = ''
              When using both wireless and static IP configuration, they must use the same interface.
              Currently configured:
                wireless interface: ${if cfg.wireless != null then cfg.wireless.interface else "none"}
                static IP interface: ${if cfg.staticConfig != null then cfg.staticConfig.interface else "none"}
            '';
          }
        ];

        # Define sops secrets for wireless networks
        sops.secrets = lib.mkIf (cfg.wireless != null) {
          "wireless/fairphone" = { };
          "wireless/hackerspace" = { };
          "wireless/beverweg" = { };
          "wireless/eduroam" = { };
        };

        environment.systemPackages = with pkgs; [
          wpa_supplicant_gui
        ];

        networking = {
          useDHCP = lib.mkForce (cfg.staticConfig == null);
          useNetworkd = lib.mkDefault true;

          defaultGateway = lib.mkIf (cfg.staticConfig != null) {
            address = cfg.staticConfig.gateway;
            interface = cfg.staticConfig.interface;
          };

          firewall = {
            enable = lib.mkDefault true;
            allowedTCPPorts = cfg.firewallPorts;
          };

          interfaces = lib.mkIf (cfg.staticConfig != null) {
            ${cfg.staticConfig.interface}.ipv4.addresses = [
              {
                address = cfg.staticConfig.address;
                prefixLength = 24;
              }
            ];
          };

          nameservers = lib.mkIf (cfg.DOHServers != null) [
            "127.0.0.1"
            "::1"
          ];

          wireless = lib.mkIf (cfg.wireless != null) {
            enable = true;
            interfaces = [ cfg.wireless.interface ];
            userControlled = true;

            # Use sops-managed secrets file for WiFi passwords
            secretsFile = config.sops.templates."wireless-secrets".path;

            networks = {
              "Jorrit's Fairphone" = {
                priority = 20;
                pskRaw = "ext:FAIRPHONE_PSK";
                authProtocols = [ "WPA-PSK" ];
              };
              "hackerspace024" = {
                priority = 10;
                pskRaw = "ext:HACKERSPACE_PSK";
                authProtocols = [ "WPA-PSK" ];
              };
              "Beverweg 20" = {
                priority = 10;
                pskRaw = "ext:BEVERWEG_PSK";
                authProtocols = [ "WPA-PSK" ];
              };
              "eduroam" = {
                priority = 10;
                authProtocols = [ "WPA-EAP" ];
                auth = ''
                  eap=PEAP
                  ca_cert="/etc/ssl/certs/ca-bundle.crt"
                  identity="jorrit.vanderheide@ru.nl"
                  password=ext:EDUROAM_PSK
                  altsubject_match="DNS:eduroam.ru.nl"
                  phase2="auth=MSCHAPV2"
                  anonymous_identity="anonymous@ru.nl"
                '';
              };
            };
          };
        };

        # Create secrets file template with sops secrets
        sops.templates."wireless-secrets" = lib.mkIf (cfg.wireless != null) {
          content = ''
            FAIRPHONE_PSK=${config.sops.placeholder."wireless/fairphone"}
            HACKERSPACE_PSK=${config.sops.placeholder."wireless/hackerspace"}
            BEVERWEG_PSK=${config.sops.placeholder."wireless/beverweg"}
            EDUROAM_PSK=${config.sops.placeholder."wireless/eduroam"}
          '';
          mode = "0400";
          owner = "wpa_supplicant";
        };

        # Disable systemd-resolved when using dnscrypt-proxy (NixOS best practice)
        services.resolved.enable = lib.mkIf (cfg.DOHServers != null) false;

        services.dnscrypt-proxy = lib.mkIf (cfg.DOHServers != null) {
          enable = true;
          settings = {
            ipv6_servers = true;
            require_dnssec = true;

            listen_addresses = [
              "127.0.0.1:53"
              "[::1]:53"
            ];

            sources.public-resolvers = {
              cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
              minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";

              urls = [
                "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
                "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
              ];
            };

            # See list at: https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md
            server_names = cfg.DOHServers;
          };
        };

        systemd.services = lib.optionalAttrs (cfg.wireless != null) {
          # Ensure wpa_supplicant waits for sops template
          "wpa_supplicant-${cfg.wireless.interface}" = {
            after = [ "sops-install-secrets.service" ];
            wants = [ "sops-install-secrets.service" ];
          };
        };
      };
    };
}
