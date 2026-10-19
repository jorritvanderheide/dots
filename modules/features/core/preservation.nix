{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.preservation =
    {
      config,
      ...
    }:
    let
      cfg = config.my.preservation;
      normalUsers = lib.attrNames (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);

      # Nested paths (those containing a /) need their parent dir created too.
      withParentConfig =
        key:
        map (
          path:
          if lib.hasInfix "/" path then
            {
              ${key} = path;
              configureParent = true;
            }
          else
            path
        );
    in
    {
      imports = [
        inputs.preservation.nixosModules.preservation

        # Short names for the system's lists in preservation's own options,
        # which take a path or an attrset ({ directory; user; mode; ... }).
        (lib.mkAliasOptionModule
          [ "my" "preservation" "systemDirectories" ]
          [ "preservation" "preserveAt" "/persist/system" "directories" ]
        )
        (lib.mkAliasOptionModule
          [ "my" "preservation" "systemFiles" ]
          [ "preservation" "preserveAt" "/persist/system" "files" ]
        )
      ];

      # Every normal user gets these, under their home.
      options.my.preservation = {
        homeDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional home directories to persist across reboots";
        };

        homeFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional home files to persist across reboots";
        };
      };

      config = {
        boot = {
          tmp.cleanOnBoot = lib.mkDefault true;

          initrd.systemd = {
            enable = true;

            # Preservation's /etc/machine-id symlink dangles until its target
            # exists, and systemd can't write a fresh ID through a dangling
            # symlink. Without one, dbus-broker refuses to start, and every
            # D-Bus service fails with it. Seeded from the hostname once
            # /persist is mounted ("f" leaves an existing ID alone), before
            # the real root's systemd reads it.
            tmpfiles.settings.machine-id."/sysroot/persist/system/etc/machine-id".f = {
              argument = builtins.substring 0 32 (builtins.hashString "sha256" config.networking.hostName);
              mode = "0444";
            };
          };
        };

        # Every database of whichever services turn PostgreSQL on (Immich)
        # lives here; declared once, so no two services claim it.
        my.preservation.systemDirectories = lib.mkIf config.services.postgresql.enable [
          {
            directory = "/var/lib/postgresql";
            group = "postgres";
            mode = "0750";
            user = "postgres";
          }
        ];

        preservation = {
          enable = true;

          preserveAt."/persist" = {
            users = lib.genAttrs normalUsers (_username: {
              commonMountOptions = [
                "x-gvfs-hide"
                "x-gdu.hide"
              ];

              directories = [
                "Documents"
                "Downloads"
                "Pictures"
                "Videos"
              ]
              ++ withParentConfig "directory" cfg.homeDirectories;

              files = [
                ".screenrc"
              ]
              ++ withParentConfig "file" cfg.homeFiles;
            });
          };

          preserveAt."/persist/system" = {
            commonMountOptions = [
              "x-gvfs-hide"
              "x-gdu.hide"
            ];

            directories = [
              {
                directory = "/etc/nixos";
                group = "nixos";
                mode = "0775";
              }
              "/var/log"
              {
                configureParent = true;
                directory = "/var/lib/nixos";
                inInitrd = true;
              }
              "/var/lib/systemd/backlight"
              "/var/lib/systemd/coredump"
              "/var/lib/systemd/timers"
              "/var/lib/systemd/timesync"
            ];

            files = [
              {
                configureParent = true;
                file = "/etc/machine-id";
                how = "symlink";
                inInitrd = true;
              }
              {
                configureParent = true;
                file = "/var/lib/systemd/random-seed";
                how = "symlink";
                inInitrd = true;
              }
            ];
          };
        };

        systemd.tmpfiles.rules = [
          "d /persist/home 0755 root root -"
          # A DynamicUser service's state (Prowlarr's, ntfy's) has no fixed
          # owner, so it is persisted 0777. Preservation creates its parent
          # 0755, which would let anyone in. "z" leaves a host without one alone.
          "z /persist/system/var/lib/private 0700 root root -"
        ];

        # Pinned so `install.sh` can chown /etc/nixos to this GID from the
        # live ISO, where the name "nixos" doesn't resolve.
        users.groups.nixos.gid = 3000;
      };
    };
}
