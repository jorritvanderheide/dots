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
      cfg = config.features.impermanence;
    in
    {
      imports = [
        inputs.impermanence.nixosModules.impermanence
      ];

      options.features.impermanence = {
        systemFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional system files to persist in /persist";
        };

        systemDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional system directories to persist in /persist";
        };
      };

      config = {
        programs.fuse.userAllowOther = true;

        boot = {
          tmp.cleanOnBoot = lib.mkDefault true;

          initrd.systemd = {
            enable = true;

            services.rollback = {
              description = "Rollback ZFS root subvolume to pristine state";
              wantedBy = [ "initrd.target" ];
              after = [
                "systemd-cryptsetup@crypted.service"
                "zfs-import-zroot.service"
              ];
              before = [ "sysroot.mount" ];
              path = [ config.boot.zfs.package ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";

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
              cfg = config.features.impermanence;
            in
            {
              options.features.impermanence = {
                homeFiles = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Additional files to persist in home directory";
                };

                homeDirectories = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Additional directories to persist in home directory";
                };
              };

              config.home.persistence."/persist" = {
                directories = [
                  "Downloads"
                  "Documents"
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
