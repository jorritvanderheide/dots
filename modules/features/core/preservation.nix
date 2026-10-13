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
        key: entries:
        map (
          entry:
          if lib.isString entry && lib.hasInfix "/" entry then
            {
              ${key} = entry;
              configureParent = true;
            }
          else
            entry
        ) entries;
    in
    {
      imports = [
        inputs.preservation.nixosModules.preservation
      ];

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

        systemDirectories = lib.mkOption {
          type = lib.types.listOf (
            lib.types.either lib.types.str (
              lib.types.submodule {
                options = {
                  configureParent = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether to also create/own the parent directory (needed for nested paths).";
                  };

                  directory = lib.mkOption {
                    type = lib.types.str;
                    description = "Absolute path of the directory to persist across reboots.";
                  };

                  group = lib.mkOption {
                    type = lib.types.str;
                    default = "root";
                    description = "Group of the persisted directory.";
                  };

                  how = lib.mkOption {
                    type = lib.types.str;
                    default = "bindmount";
                    description = "Preservation method passed through to the preservation module (e.g. bindmount).";
                  };

                  inInitrd = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether the directory must be available already in the initrd.";
                  };

                  mode = lib.mkOption {
                    type = lib.types.str;
                    default = "0755";
                    description = "Permission bits for the persisted directory.";
                  };

                  user = lib.mkOption {
                    type = lib.types.str;
                    default = "root";
                    description = "Owner of the persisted directory.";
                  };
                };
              }
            )
          );
          default = [ ];
          description = "Additional system directories to persist across reboots";
        };

        systemFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional system files to persist across reboots";
        };
      };

      config = {
        # Pinned so `install.sh` can chown /etc/nixos to this GID from the
        # live ISO, where the name "nixos" doesn't resolve.
        users.groups.nixos.gid = 3000;

        boot = {
          tmp.cleanOnBoot = lib.mkDefault true;

          initrd.systemd = {
            enable = true;

            # The /etc/machine-id symlink below dangles until its target
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
            ]
            ++ cfg.systemDirectories;

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
            ]
            ++ cfg.systemFiles;
          };
        };

        systemd.tmpfiles.rules = [
          "d /persist/home 0755 root root -"
          # A DynamicUser service's state (Prowlarr's, ntfy's) has no fixed
          # owner, so it is persisted 0777. Preservation creates its parent
          # 0755, which would let anyone in. "z" leaves a host without one alone.
          "z /persist/system/var/lib/private 0700 root root -"
        ];
      };
    };
}
