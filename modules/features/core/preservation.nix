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

      # Enable configureParent for nested paths (those containing a /)
      withParentConfig =
        entries:
        map (
          entry:
          if lib.isString entry && lib.hasInfix "/" entry then
            {
              directory = entry;
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
        systemFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional system files to persist across reboots";
        };

        systemDirectories = lib.mkOption {
          type = lib.types.listOf (
            lib.types.either lib.types.str (
              lib.types.submodule {
                options = {
                  directory = lib.mkOption { type = lib.types.str; };
                  user = lib.mkOption {
                    type = lib.types.str;
                    default = "root";
                  };
                  group = lib.mkOption {
                    type = lib.types.str;
                    default = "root";
                  };
                  mode = lib.mkOption {
                    type = lib.types.str;
                    default = "0755";
                  };
                  configureParent = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };
                  how = lib.mkOption {
                    type = lib.types.str;
                    default = "bindmount";
                  };
                  inInitrd = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };
                };
              }
            )
          );
          default = [ ];
          description = "Additional system directories to persist across reboots";
        };

        homeFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional home files to persist across reboots";
        };

        homeDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional home directories to persist across reboots";
        };
      };

      config = {
        users.groups.nixos = { };

        systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ]; # Systemd-machine-id-commit would fail with a bind-mounted machine-id

        boot = {
          tmp.cleanOnBoot = lib.mkDefault true;

          initrd.systemd = {
            enable = true;

            services.rollback = {
              before = [ "sysroot.mount" ];
              description = "Rollback ZFS root subvolume to pristine state";
              unitConfig.DefaultDependencies = "no";
              path = [ config.boot.zfs.package ];
              serviceConfig.Type = "oneshot";
              wantedBy = [ "initrd.target" ];

              after = [
                "systemd-cryptsetup@crypted.service"
                "zfs-import-zroot.service"
              ];

              script = ''
                zfs rollback -r zroot/root@empty
              '';
            };
          };
        };

        preservation = {
          enable = true;

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
                directory = "/var/lib/nixos";
                how = "symlink";
                inInitrd = true;
                configureParent = true;
              }
              "/var/lib/systemd/backlight"
              "/var/lib/systemd/coredump"
              "/var/lib/systemd/timers"
              "/var/lib/systemd/timesync"
            ]
            ++ cfg.systemDirectories;

            files = [
              {
                file = "/etc/machine-id";
                how = "symlink";
                inInitrd = true;
                configureParent = true;
              }
              {
                file = "/var/lib/systemd/random-seed";
                how = "symlink";
                inInitrd = true;
                configureParent = true;
              }
            ]
            ++ cfg.systemFiles;
          };

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
              ++ withParentConfig cfg.homeDirectories;

              files = [
                ".screenrc"
              ]
              ++ cfg.homeFiles;
            });
          };
        };

        # Ensure the /persist/home directory exists
        systemd.tmpfiles.rules = [
          "d /persist/home 0755 root root -"
        ];
      };
    };
}
