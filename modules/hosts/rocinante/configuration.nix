{ inputs, lib, ... }:
let
  facterPath = inputs.self + "/modules/hosts/rocinante/facter.json";
  facterReport = lib.importJSON facterPath;
in
{
  flake.nixosConfigurations.rocinante = inputs.nixpkgs.lib.nixosSystem {
    modules =
      (with inputs.self.nixosModules; [
        # Core
        boot
        disk
        facter
        home-manager
        kernel
        overlays
        preservation
        secrets
        zfs

        # System
        locale
        networking
        ssh
        sudo
        vpn

        # Hardware
        bluetooth
        firmware
        power
        sound

        # Desktop
        app-launch
        clipboard
        compositor
        desktop-shell
        idle
        keybinds
        keyboard-remap
        launcher
        lockscreen
        polkit
        session
        theming

        # Dev
        coding-agent
        direnv
        git
        nix
        virtualization
        worktrunk

        # Shell
        cli-tools
        prompt
        shell

        # Apps
        browser
        cad
        editor
        email
        gaming
        media-player
        messaging
        music-player
        notes
        password-manager
        social
        terminal

        # Users
        jorrit
      ])
      ++ [
        # Hardware-specific
        inputs.nixos-hardware.nixosModules.framework-13th-gen-intel

        # Host configuration
        (
          { config, pkgs, ... }:
          {
            ## System
            networking.hostName = "rocinante";
            nixpkgs.hostPlatform = facterReport.system;
            system.stateVersion = "26.05";

            ## Hardware
            boot.blacklistedKernelModules = [ "kvm-amd" ];
            boot.initrd.availableKernelModules = [ "tpm_tis" ];
            environment.systemPackages = with pkgs; [ intel-media-driver ];
            services.fwupd.extraRemotes = [ "lvfs-testing" ];

            ## Persistence
            preservation.preserveAt."/persist/system".directories = [
              {
                directory = "/etc/nixos";
                user = "jorrit";
                group = "users";
              }
            ];

            ## WiFi networks
            sops.secrets = {
              "wireless/fairphone" = { };
              "wireless/hackerspace" = { };
              "wireless/beverweg" = { };
              "wireless/eduroam" = { };
            };

            networking.wireless = {
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

            sops.templates."wireless-secrets" = {
              content = ''
                FAIRPHONE_PSK=${config.sops.placeholder."wireless/fairphone"}
                HACKERSPACE_PSK=${config.sops.placeholder."wireless/hackerspace"}
                BEVERWEG_PSK=${config.sops.placeholder."wireless/beverweg"}
                EDUROAM_PSK=${config.sops.placeholder."wireless/eduroam"}
              '';
              mode = "0400";
              owner = "wpa_supplicant";
            };

            ## Display outputs
            home-manager.sharedModules = [
              {
                programs.niri.settings.outputs = {
                  "eDP-1" = {
                    scale = 1.175;
                    position = {
                      x = 0;
                      y = 0;
                    };
                  };
                  "LG Electronics LG HDR 4K 210MAZVRJG93" = {
                    focus-at-startup = true;
                    scale = 1.25;
                    position = {
                      x = 1920;
                      y = -1720;
                    };
                  };
                  "LG Electronics LG HDR 4K 0x0004C67F" = {
                    focus-at-startup = true;
                    scale = 1.25;
                    position = {
                      x = 1920;
                      y = -1720;
                    };
                  };
                  "Philips Consumer Electronics Company 86BDL4550D 0x01010101" = {
                    scale = 2;
                    position = {
                      x = -1097;
                      y = -613;
                    };
                  };
                  "Sharp Corporation PN-60TA3/B3 0x0CAE2D06" = {
                    scale = 1.5;
                    position = {
                      x = -1097;
                      y = -613;
                    };
                  };
                };
              }
            ];

            ## Module settings
            my.session.autologinuser = "jorrit";

            my.compositor = {
              name = "niri";
              wallpaper = inputs.self + "/assets/wallpapers/cabin.jpg";
            };

            my.preservation.systemDirectories = [
              "/var/lib/fprint"
            ];

            my.networking = {
              DOHServers = [ "mullvad-all-doh" ];
              wireless.interface = "wlp170s0";
              firewallPorts = [
                8188 # Yivi
                8189
              ];
            };

            my.power.laptop.enable = true;
          }
        )
      ];
  };
}
