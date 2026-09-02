{
  inputs,
  ...
}:
{
  flake.nixosModules.networking =
    { pkgs, ... }:
    {
      config = {
        # Standalone GUI for viewing/editing NetworkManager connection profiles
        # (e.g. ad-hoc Wi-Fi not declared below) -- no systray needed.
        environment.systemPackages = [ pkgs.networkmanagerapplet ];

        networking = {
          # NetworkManager runs its own DHCP client per-interface; without this
          # NixOS's global dhcpcd.service also runs and races it on the same
          # interface, producing two conflicting default routes/leases (seen
          # on iotroam: two "default via" routes with different src IPs).
          # (networking.useDHCP is not the relevant knob here -- enabling
          # NetworkManager already forces that to false internally. dhcpcd.enable
          # is a separate option that defaults to true regardless.)
          dhcpcd.enable = false;

          networkmanager = {
            enable = true;

            ensureProfiles = {
              environmentFiles = [ "/run/wireless-secrets.env" ];

              profiles = {
                beverweg = {
                  ipv4.method = "auto";
                  ipv6.method = "auto";

                  connection = {
                    id = "Beverweg 20";
                    type = "wifi";
                    permissions = "user:jorrit:";
                  };

                  wifi = {
                    mode = "infrastructure";
                    ssid = "Beverweg 20";
                  };

                  wifi-security = {
                    key-mgmt = "wpa-psk";
                    psk = "$BEVERWEG_PSK";
                  };
                };

                eduroam = {
                  ipv4.method = "auto";
                  ipv6.method = "auto";

                  "802-1x" = {
                    anonymous-identity = "anonymous@ru.nl";
                    # ca-cert intentionally left unset: RU's RADIUS backend is
                    # inconsistent about sending its intermediate cert chain, and
                    # wpa_supplicant's OpenSSL backend won't fill the gap from a
                    # local ca-cert store during a live handshake (verified: even
                    # a byte-for-byte correct bundle, extracted from RU's own
                    # eduroam CAT installer, didn't help -- see eduroam-ca.pem,
                    # kept around for whenever RU's server-side issue is fixed
                    # and validation can be turned back on).
                    # ca-cert = "${./eduroam-ca.pem}";
                    eap = "peap";
                    identity = "$EDUROAM_IDENTITY";
                    password = "$EDUROAM_PSK";
                    phase2-auth = "mschapv2";
                  };

                  connection = {
                    id = "eduroam";
                    type = "wifi";
                    permissions = "user:jorrit:";
                  };

                  wifi = {
                    mode = "infrastructure";
                    ssid = "eduroam";
                  };

                  wifi-security = {
                    key-mgmt = "wpa-eap";
                  };
                };

                hotspot = {
                  ipv4.method = "auto";
                  ipv6.method = "auto";

                  connection = {
                    autoconnect-priority = 100;
                    id = "Jorrit's Fairphone";
                    type = "wifi";
                    permissions = "user:jorrit:";
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
                    type = "wifi";
                    permissions = "user:jorrit:";
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
          };
        };

        # NM's own ensure-profiles unit -- just point it at the env file
        # wireless-secrets produces, and make it wait for that.
        systemd.services.NetworkManager-ensure-profiles = {
          after = [ "wireless-secrets.service" ];
          wants = [ "wireless-secrets.service" ];
        };

        # Same bare-chroot reason as set-password-root (see mkSopsService)
        # this can't use sops-nix's own sops.secrets/sops.templates for
        # NetworkManager-ensure-profiles' environmentFiles -- decrypts
        # straight into /run itself instead.
        systemd.services.wireless-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt wireless PSKs for NetworkManager's declarative profiles";
          extraServiceConfig.UMask = "0177";

          # Each extract is its own assignment statement, not inlined into
          # the echo -- `echo "X=$(failing_cmd)"` swallows failing_cmd's
          # exit status (echo itself still succeeds), so `set -e` never
          # catches a decrypt failure and the service "succeeds" having
          # written empty PSKs. A bare `VAR="$(failing_cmd)"` assignment
          # does propagate the failure.
          script = ''
            BEVERWEG_PSK="$(sops_extract wireless_beverweg)"
            EDUROAM_IDENTITY="$(sops_extract wireless_eduroam_identity)"
            EDUROAM_PSK="$(sops_extract wireless_eduroam)"
            HOTSPOT_PSK="$(sops_extract wireless_hotspot)"
            IOTROAM_PSK="$(sops_extract wireless_iotroam)"
            {
              echo "BEVERWEG_PSK=$BEVERWEG_PSK"
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
