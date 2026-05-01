{
  lib,
  ...
}:
{
  flake.nixosModules.networking =
    {
      config,
      ...
    }:
    let
      cfg = config.my.networking;
    in
    {
      options.my.networking = {
        DOHServers = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          description = "DNS-over-HTTPS server names for dnscrypt-proxy";
          default = null;
        };

        hosts = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          description = "Mapping of IP addresses to hostnames";
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
          description = "Static network configuration, or null for DHCP";
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
                          description = "Network priority, higher values are preferred";
                        };

                        psk = lib.mkOption {
                          type = lib.types.str;
                          description = "Pre-shared key for authentication";
                        };
                      };
                    }
                  );
                  default = { };
                  description = "Wireless networks and their credentials";
                };
              };
            }
          );
          default = null;
          description = "Wireless network configuration, or null to disable";
        };

        firewallPorts = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.port);
          default = { };
          example = {
            wlp170s0 = [
              8188
              8189
            ];
          };
          description = ''
            TCP ports to open in the firewall, scoped per interface.
            Use the interface name as key. Per-SSID scoping is not supported;
            ports open whenever the interface is up.
          '';
        };
      };

      config = {
        assertions = [
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

        # Persist dnscrypt-proxy cache across reboots
        # Note: /var/lib/dnscrypt-proxy is a symlink to private/dnscrypt-proxy
        my.preservation.systemDirectories = lib.mkIf (cfg.DOHServers != null) [
          "/var/lib/private/dnscrypt-proxy"
        ];

        # Fix permissions for /var/lib/private (systemd requires 0700 for StateDirectory)
        systemd.tmpfiles.rules = lib.mkIf (cfg.DOHServers != null) [
          "d /var/lib/private 0700 root root -"
        ];

        # Define sops secrets for wireless networks
        sops.secrets = lib.mkIf (cfg.wireless != null) {
          "wireless/fairphone" = { };
          "wireless/hackerspace" = { };
          "wireless/beverweg" = { };
          "wireless/eduroam" = { };
        };

        # Ensure wpa_supplicant user exists early enough for sops template ownership
        users.users.wpa_supplicant = lib.mkIf (cfg.wireless != null) {
          isSystemUser = true;
          group = "wpa_supplicant";
        };
        users.groups.wpa_supplicant = lib.mkIf (cfg.wireless != null) { };

        networking = {
          useDHCP = lib.mkForce (cfg.staticConfig == null);
          useNetworkd = lib.mkDefault true;

          defaultGateway = lib.mkIf (cfg.staticConfig != null) {
            address = cfg.staticConfig.gateway;
            inherit (cfg.staticConfig) interface;
          };

          firewall = {
            enable = lib.mkDefault true;
            interfaces = lib.mapAttrs (_: ports: { allowedTCPPorts = ports; }) cfg.firewallPorts;
          };

          interfaces = lib.mkIf (cfg.staticConfig != null) {
            ${cfg.staticConfig.interface}.ipv4.addresses = [
              {
                inherit (cfg.staticConfig) address;
                prefixLength = 24;
              }
            ];
          };

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

        # Use systemd-resolved as DNS orchestrator for split DNS:
        #   *.ts.net        → Tailscale (automatic via accept-dns)
        #   everything else → dnscrypt-proxy (DOH)
        services.resolved = lib.mkIf (cfg.DOHServers != null) {
          enable = true;
          settings.Resolve = {
            DNSSEC = "false"; # dnscrypt-proxy handles DNSSEC validation
            DNS = [ "127.0.0.1:5354" ];
            DNSStubListener = "yes";
            FallbackDNS = [ ];
          };
        };

        services.dnscrypt-proxy = lib.mkIf (cfg.DOHServers != null) {
          enable = true;
          settings = {
            ipv6_servers = true;
            require_dnssec = true;

            # Listen on 5354 — resolved handles port 53 and routes here (5353 is mDNS)
            listen_addresses = [
              "127.0.0.1:5354"
              "[::1]:5354"
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

        systemd.services = lib.mkMerge [
          (lib.optionalAttrs (cfg.wireless != null) {
            # Ensure wpa_supplicant waits for sops template
            "wpa_supplicant-${cfg.wireless.interface}" = {
              after = [ "sops-install-secrets.service" ];
              wants = [ "sops-install-secrets.service" ];
            };
          })
          {
            # Don't wait for network before starting multi-user.target
            systemd-networkd-wait-online = {
              wantedBy = lib.mkForce [ ];
              requiredBy = lib.mkForce [ ];
            };

            # Disable unnecessary network wait service
            NetworkManager-wait-online.enable = false;
          }
        ];
      };
    };
}
