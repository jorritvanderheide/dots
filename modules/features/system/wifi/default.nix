{
  inputs,
  ...
}:
{
  # The laptop's Wi-Fi networks. A module of their own so the server, which
  # is wired, never decrypts their passwords.
  flake.nixosModules.wifi =
    { config, lib, ... }:
    let
      # The variable each profile uses, and its sops key.
      secrets = {
        EDUROAM_IDENTITY = "wireless_eduroam_identity";
        EDUROAM_PSK = "wireless_eduroam";
        HACKERSPACE_PSK = "wireless_hackerspace";
        HOTSPOT_PSK = "wireless_hotspot";
        IOTROAM_PSK = "wireless_iotroam";
        WIFI_HOME_24_SSID = "wireless_home_24_ssid";
        WIFI_HOME_PSK = "wireless_home";
        WIFI_HOME_SSID = "wireless_home_ssid";
      };
    in
    {
      config = {
        sops.secrets = lib.genAttrs (lib.attrValues secrets) (_: { });

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ config.sops.templates."wireless.env".path ];

          profiles = {
            eduroam = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              "802-1x" = {
                anonymous-identity = "anonymous@ru.nl";
                domain-suffix-match = "ru.nl";
                eap = "peap";
                identity = "$EDUROAM_IDENTITY";
                password = "$EDUROAM_PSK";
                phase2-auth = "mschapv2";

                # GÉANT TLS RSA 1, which issues RU's RADIUS certificate
                # (crt.harica.gr/HARICA-GEANT-TLS-R1.cer), then HARICA TLS
                # RSA Root CA 2021 (from Mozilla's store) behind it:
                # wpa_supplicant only takes a chain that ends in a
                # self-signed root, so the intermediate alone fails. With
                # it in the file, a server that leaves it out still passes.
                ca-cert = "${./eduroam-ca.pem}";
              };

              connection = {
                id = "eduroam";
                permissions = "user:${inputs.self.lib.site.user}:";
                type = "wifi";
              };

              wifi = {
                mode = "infrastructure";
                ssid = "eduroam";
              };

              wifi-security = {
                key-mgmt = "wpa-eap";
              };
            };

            hackerspace = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              connection = {
                id = "Hackerspace Nijmegen";
                permissions = "user:${inputs.self.lib.site.user}:";
                type = "wifi";
              };

              wifi = {
                mode = "infrastructure";
                ssid = "Hackerspace Nijmegen";
              };

              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$HACKERSPACE_PSK";
              };
            };

            home = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              connection = {
                autoconnect-priority = 10;
                id = "Home";
                permissions = "user:${inputs.self.lib.site.user}:";
                type = "wifi";
              };

              wifi = {
                mode = "infrastructure";
                ssid = "$WIFI_HOME_SSID";
              };

              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_HOME_PSK";
              };
            };

            home-24 = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              connection = {
                id = "Home 2.4";
                permissions = "user:${inputs.self.lib.site.user}:";
                type = "wifi";
              };

              wifi = {
                mode = "infrastructure";
                ssid = "$WIFI_HOME_24_SSID";
              };

              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$WIFI_HOME_PSK";
              };
            };

            hotspot = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              connection = {
                autoconnect-priority = 100;
                id = "Jorrit's Fairphone";
                permissions = "user:${inputs.self.lib.site.user}:";
                type = "wifi";
              };

              wifi = {
                mode = "infrastructure";
                ssid = "Jorrit's Fairphone";
              };

              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$HOTSPOT_PSK";
              };
            };

            iotroam = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              connection = {
                autoconnect-priority = 10;
                id = "iotroam";
                permissions = "user:${inputs.self.lib.site.user}:";
                type = "wifi";
              };

              wifi = {
                mode = "infrastructure";
                ssid = "iotroam";
              };

              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$IOTROAM_PSK";
              };
            };
          };
        };

        # The env file NM's own ensure-profiles unit reads.
        sops.templates."wireless.env" = {
          restartUnits = [ "NetworkManager-ensure-profiles.service" ];

          content = lib.concatStrings (
            lib.mapAttrsToList (var: key: "${var}=${config.sops.placeholder.${key}}\n") secrets
          );
        };
      };
    };
}
