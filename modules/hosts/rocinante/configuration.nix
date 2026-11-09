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

        # Desktop
        alerts

        # System
        auto-brightness
        bluetooth
        firmware
        label-printer
        power
        sound
        wifi
        yubikey

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
        cad
        editor
        email
        file-sync
        media-player
        messaging
        music-player
        password-manager
        photo-editor
        terminal

        # Hardware
        rocinante-hardware

        # Users
        jorrit
      ])
      ++ [
        (
          { config, ... }:
          {
            my.power.laptop.enable = true;
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
                };

                # PhD office monitor
                "LG Electronics LG HDR 4K 0x00078084" = {
                  focus-at-startup = true;
                  scale = 1.25;
                };

                # Office monitor
                "LG Electronics LG HDR 4K 210MAZVRJG93" = {
                  focus-at-startup = true;
                  scale = 1.25;
                };
              };
            };

            my.offsite-backup = {
              enable = true;

              paths = [
                "/persist/home/jorrit/${config.my.research.vaultPath}"
                "/persist/home/jorrit/Zotero"
              ];
            };

            # /persist is all that survives the boot-time rollback, and the
            # offsite backup (my.offsite-backup) is its only copy off this disk.
            # The research modules declare what state they need kept but not
            # how; this machine persists it with preservation.
            my.preservation.homeDirectories = config.my.research.statePaths;

            my.research = {
              institution = {
                ezproxyPrefix = "https://login.ru.idm.oclc.org/login?qurl=";
                iconUrl = "https://www.ru.nl/favicon.ico";
                librarySearchUrl = "https://ru.on.worldcat.org/search?queryString={searchTerms}";
                openurlResolver = "https://ru.on.worldcat.org/atoztitles/link";
              };
            };

            # Resolves .local names, to reach the installer ISO as
            # yubinstall.local (README, "Installation").
            services.avahi = {
              enable = true;
              nssmdns4 = true;
            };
          }
        )
      ];
  };
}
