{
  inputs,
  lib,
  ...
}:
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
        nix
        preservation
        secrets
        zfs

        # System
        bluetooth
        firmware
        locale
        networking
        power
        sound
        ssh
        sudo
        vpn

        # Desktop
        app-launch
        compositor
        files
        keybinds
        keyboard-remap
        desktop-shell
        notifications
        polkit
        session
        theming

        # Dev
        coding-agent
        direnv
        git
        virtualization

        # Shell
        cli-tools
        shell

        # Apps
        browser
        editor
        email
        media-player
        messaging
        music-player
        notes
        password-manager
        terminal
        yubikey

        # Users
        jorrit
      ])
      ++ [
        inputs.nixos-hardware.nixosModules.framework-13th-gen-intel

        (_: {
          networking.hostName = "rocinante";
          nixpkgs.hostPlatform = facterReport.system;
          system.stateVersion = "26.05";

          my.desktop-shell.lockOnStartup = true;
          my.power.laptop.enable = true;
          my.session.autologinuser = "jorrit";

          my.compositor = {
            outputs = {
              # Laptop screen
              "eDP-1" = {
                scale = 1.175;

                position = {
                  x = 0;
                  y = 0;
                };
              };

              # Home monitor
              "LG Electronics LG HDR 4K 0x0004C67F" = {
                focus-at-startup = true;
                scale = 1.25;

                position = {
                  x = -576;
                  y = -1728;
                };
              };

              # Office monitor
              "LG Electronics LG HDR 4K 210MAZVRJG93" = {
                focus-at-startup = true;
                scale = 1.25;

                position = {
                  x = -576;
                  y = -1728;
                };
              };

              # Meeting room 18th floor
              "Philips Consumer Electronics Company 86BDL4550D 0x01010101" = {
                scale = 2;

                position = {
                  x = 0;
                  y = -1080;
                };
              };

              # Corner office 19th floor
              "Sharp Corporation PN-60TA3/B3 0x0CAE2D06" = {
                scale = 1.5;

                position = {
                  x = 320;
                  y = -720;
                };
              };
            };
          };

          my.ssh.knownHosts.dapple = {
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUeoBcfcYFUgUVYghcX5iksqBYrwIB/fgB/6QTucQ0L";

            hostNames = [
              "dapple"
              "100.64.0.1"
            ];
          };

          # Public halves only -- private keys live in the Bitwarden SSH
          # agent (ssh-add -L to re-derive these if they're ever lost).
          my.ssh.identityFiles = {
            "git@codeberg.org.pub" =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDBw6g7ruZDtFHuzlzPWLKmN8yeQTrrx88eC92ECMDC git@codeberg.org";
            "git@github.com.pub" =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW60Nybd6kk9zSurQJmpUODQDw0p41Pc/G/kt/CQ/Qy git@github.com";
            "git@gitlab.science.ru.nl.pub" =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK7PikkKt9lBCZDYpCZm8fFPx+oZ1EQWPhlzREkboFA git@gitlab.science.ru.nl";
          };

          my.vpn.loginServer = "https://vpn.bw20.nl";
        })
      ];
  };
}
