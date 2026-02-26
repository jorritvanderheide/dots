{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.impermanence =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.impermanence;
    in
    {
      imports = [
        inputs.impermanence.nixosModules.impermanence
      ];

      options.settings.impermanence = {
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
      };

      config = {
        programs.fuse.userAllowOther = true;

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

        environment.persistence."/persist/system" = {
          hideMounts = true;

          directories = [
            "/etc/nixos"
            "/etc/ssh"
            "/var/log"
            "/var/lib/nixos"
            "/var/lib/systemd"
          ]
          ++ cfg.systemDirectories;

          files = [
            "/etc/machine-id"
          ]
          ++ cfg.systemFiles;
        };

        # Ensure the /persist/home directory exists
        systemd.tmpfiles.rules = [
          "d /persist/home 0755 root root -"
        ];

        home-manager.sharedModules = [
          (
            { config, ... }:
            let
              cfg = config.settings.impermanence;
            in
            {
              options.settings.impermanence = {
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

              config.home.persistence."/persist" = {
                directories = [
                  "Documents"
                  "Downloads"
                  "Pictures"
                  "Videos"
                ]
                ++ cfg.homeDirectories;

                files = [
                  ".screenrc"
                ]
                ++ cfg.homeFiles;
              };
            }
          )
        ];
      };
    };
}
