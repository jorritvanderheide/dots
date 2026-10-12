{
  inputs,
  ...
}:
{
  # The laptop's Wi-Fi networks. A module of their own so the server, which
  # is wired, never decrypts their passwords.
  flake.nixosModules.wifi =
    { pkgs, ... }:
    {
      config = {
        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ "/run/wireless-secrets.env" ];

          profiles = {
            eduroam = {
              ipv4.method = "auto";
              ipv6.method = "auto";

              "802-1x" = {
                anonymous-identity = "anonymous@ru.nl";

                # No ca-cert: RU's RADIUS backend is inconsistent about
                # sending its intermediate cert chain, and wpa_supplicant's
                # OpenSSL backend won't fill the gap from a local CA store
                # during a live handshake (even a byte-for-byte correct
                # bundle from RU's own eduroam CAT installer didn't help).
                # Set it, from that installer, once RU's server sends the
                # whole chain.
                eap = "peap";

                identity = "$EDUROAM_IDENTITY";
                password = "$EDUROAM_PSK";
                phase2-auth = "mschapv2";
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

        # NM's own ensure-profiles unit; just point it at the env file
        # wireless-secrets produces, and make it wait for that.
        systemd.services.NetworkManager-ensure-profiles = {
          after = [ "wireless-secrets.service" ];
          wants = [ "wireless-secrets.service" ];
        };

        # Same bare-chroot reason as set-password-root (see mkSopsService)
        # this can't use sops-nix's own sops.secrets/sops.templates for
        # NetworkManager-ensure-profiles' environmentFiles; it decrypts
        # straight into /run itself instead.
        systemd.services.wireless-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt wireless PSKs for NetworkManager's declarative profiles";
          extraServiceConfig.UMask = "0177";

          # Each extract is its own assignment statement, not inlined into
          # the echo: `echo "X=$(failing_cmd)"` swallows failing_cmd's
          # exit status (echo itself still succeeds), so `set -e` never
          # catches a decrypt failure and the service "succeeds" having
          # written empty PSKs. A bare `VAR="$(failing_cmd)"` assignment
          # does propagate the failure.
          script = ''
            WIFI_HOME_PSK="$(sops_extract wireless_home)"
            WIFI_HOME_SSID="$(sops_extract wireless_home_ssid)"
            WIFI_HOME_24_SSID="$(sops_extract wireless_home_24_ssid)"
            EDUROAM_IDENTITY="$(sops_extract wireless_eduroam_identity)"
            EDUROAM_PSK="$(sops_extract wireless_eduroam)"
            HOTSPOT_PSK="$(sops_extract wireless_hotspot)"
            IOTROAM_PSK="$(sops_extract wireless_iotroam)"
            {
              echo "WIFI_HOME_PSK=$WIFI_HOME_PSK"
              echo "WIFI_HOME_SSID=$WIFI_HOME_SSID"
              echo "WIFI_HOME_24_SSID=$WIFI_HOME_24_SSID"
              echo "EDUROAM_IDENTITY=$EDUROAM_IDENTITY"
              echo "EDUROAM_PSK=$EDUROAM_PSK"
              echo "HOTSPOT_PSK=$HOTSPOT_PSK"
              echo "IOTROAM_PSK=$IOTROAM_PSK"
            } > /run/wireless-secrets.env
          '';
        };
      };
    };
}
