{
  inputs,
  ...
}:
{
  flake.nixosConfigurations.rocinante = inputs.nixpkgs.lib.nixosSystem {
    modules =
      (with inputs.self.nixosModules; [
        base
        desktop

        # System
        bluetooth
        firmware
        power
        sound
        wifi

        # Dev
        coding-agent
        direnv
        git
        virtualization

        # Research
        notes
        pdf-reader
        zotero

        # Apps
        browser
        editor
        email
        file-sync
        media-player
        messaging
        music-player
        password-manager
        photo-editor
        terminal
        yubikey

        # Users
        jorrit
      ])
      ++ [
        inputs.nixos-hardware.nixosModules.framework-13th-gen-intel

        (
          { config, ... }:
          {
            my.desktop-shell.lockOnStartup = true;
            my.power.laptop.enable = true;

            # /persist is all that survives the boot-time rollback, and the
            # offsite backup (below) is its only copy off this disk.
            # The research modules declare what state they need kept but not
            # how; this machine persists it with preservation.
            my.preservation.homeDirectories = config.my.research.statePaths;

            my.session.autologinuser = "jorrit";
            networking.hostName = "rocinante";
            system.stateVersion = "26.05";

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
                    x = 0;
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

            my.offsite-backup = {
              enable = true;

              paths = [
                "/persist/home/jorrit/Zotero"
              ];
            };

            my.research = {
              institution = {
                ezproxyPrefix = "https://login.ru.idm.oclc.org/login?qurl=";
                iconUrl = "https://www.ru.nl/favicon.ico";
                librarySearchUrl = "https://ru.on.worldcat.org/search?queryString={searchTerms}";
                openurlResolver = "https://ru.on.worldcat.org/atoztitles/link";
              };
            };

            my.ssh.knownHosts.dapple = {
              publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUeoBcfcYFUgUVYghcX5iksqBYrwIB/fgB/6QTucQ0L";

              hostNames = [
                "dapple"
                inputs.self.lib.site.dapple.lanIp
                inputs.self.lib.site.dapple.tailnetIp
              ];
            };

            # Community caches, for the laptop only: the server needs nothing
            # beyond cache.nixos.org.
            nix.settings = {
              # Signs what this host builds, so dapple accepts what
              # `ndeploy` copies to it without trusting the user who copies
              # it. Straight on /persist, like the SSH host key; generated
              # with `nix key generate-secret --key-name rocinante-1`.
              secret-key-files = [ "/persist/system/var/lib/nix-signing/key" ];

              substituters = [
                "https://nix-community.cachix.org"
                "https://numtide.cachix.org"
              ];

              trusted-public-keys = [
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
              ];
            };

            # Resolves .local names, to reach the installer ISO as
            # dots-installer.local (docs/install.md).
            services.avahi = {
              enable = true;
              nssmdns4 = true;
            };
          }
        )
      ];
  };
}
