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
        preservation
        secrets
        zfs

        # System
        clock-floor
        locale
        networking
        ssh
        sudo
        vpn

        # Services
        tailscale

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
        files
        idle
        keybinds
        keyboard-remap
        launcher
        lockscreen
        notifications
        polkit
        session
        theming

        # Dev
        coding-agent
        direnv
        git
        nix
        reticulum
        virtualization

        # Shell
        cli-tools
        prompt
        shell

        # Apps
        browser
        cad
        editor
        emacs
        email
        gaming
        media-player
        messaging
        music-player
        notes
        password-manager
        raw-editor
        slicer
        social
        terminal

        # Users
        jorrit
      ])
      ++ [
        # Hardware-specific
        inputs.nixos-hardware.nixosModules.framework-13th-gen-intel

        # Host configuration
        (_: {
          ## System
          networking.hostName = "rocinante";
          nixpkgs.hostPlatform = facterReport.system;
          system.stateVersion = "26.05";

          ## Hardware
          boot.blacklistedKernelModules = [ "kvm-amd" ];
          boot.initrd.availableKernelModules = [ "tpm_tis" ];
          # 13th gen is Gen12 graphics: use the modern media-driver only,
          # instead of nixos-hardware's default of also installing the
          # legacy intel-vaapi-driver (meant for Gen8-11).
          hardware.intelgpu.vaapiDriver = "intel-media-driver";
          services.fwupd.extraRemotes = [ "lvfs-testing" ];

          ## Other
          home-manager.users.jorrit.gtk.gtk3.bookmarks = [
            "sftp://nixos@dapple/srv/media Dapple Media"
          ];

          ## My modules
          my.idle.suspendTimeout = 1800;
          my.lockscreen.greetOnStartup = true;
          my.power.laptop.enable = true;
          my.session.autologinuser = "jorrit";
          my.sudo.fingerprintAuth = true;
          my.vpn.enable = true;

          my.compositor = {
            wallpaper = ./assets/wallpapers/cabin.jpg;

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

          my.networking = {
            DOHServers = [ "mullvad-all-doh" ];
            wireless.interface = "wlp170s0";

            firewallPorts.wlp170s0 = [
              8188 # Yivi (used on home + Radboud networks)
              8189
            ];
          };

          my.ssh.knownHosts.dapple = {
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante";

            hostNames = [
              "dapple"
              "100.64.0.1"
            ];
          };

          my.tailscale = {
            enable = true;
            loginServer = "https://vpn.bw20.nl";
          };
        })
      ];
  };
}
