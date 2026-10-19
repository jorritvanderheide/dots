_: {
  # The laptop's Wi-Fi networks. A module of their own so the server, which
  # is wired, never decrypts their passwords.
  flake.nixosModules.wifi =
    { config, lib, ... }:
    let
      # The variable each profile uses, and its sops key.
      secrets = {
        EDUROAM_IDENTITY = "wireless_eduroam_identity";
        EDUROAM_PSK = "wireless_eduroam";
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
                identity = "$EDUROAM_IDENTITY";
                password = "$EDUROAM_PSK";
                phase2-auth = "mschapv2";

                # No ca-cert: RU's RADIUS backend is inconsistent about
                # sending its intermediate cert chain, and wpa_supplicant's
                # OpenSSL backend won't fill the gap from a local CA store
                # during a live handshake (even a byte-for-byte correct
                # bundle from RU's own eduroam CAT installer didn't help).
                # Set it, from that installer, once RU's server sends the
                # whole chain.
                eap = "peap";
              };

              connection = {
                id = "eduroam";
                permissions = "user:jorrit:";
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

            home = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              connection = {
                autoconnect-priority = 10;
                id = "Home";
                permissions = "user:jorrit:";
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
                permissions = "user:jorrit:";
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
                permissions = "user:jorrit:";
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
                permissions = "user:jorrit:";
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
