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
      cfg = config.settings.preservation;
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

      options.settings.preservation = {
        systemFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional system files to persist across reboots";
        };

        systemDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
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
        preservation.enable = true;

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

        # Systemd-machine-id-commit would fail with a bind-mounted machine-id
        systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

        preservation.preserveAt."/persist/system" = {
          directories = [
            "/etc/nixos"
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
              file = "/etc/ssh/ssh_host_ed25519_key";
              how = "symlink";
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

        # Ensure the /persist/home directory exists
        systemd.tmpfiles.rules = [
          "d /persist/home 0755 root root -"
        ];

        preservation.preserveAt."/persist" = {
          users = lib.genAttrs normalUsers (_username: {
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
    };
}
