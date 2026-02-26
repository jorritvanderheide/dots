{
  inputs,
  lib,
  ...
}:
{
  flake.lib = {
    mkDisks =
      {
        device,
        diskSize,
        passwordFile ? "/tmp/secret.key",
      }:
      {
        disk.main = {
          device = device;
          type = "disk";

          content = {
            type = "gpt";

            partitions = {
              ESP = {
                size = "2G";
                type = "EF00";

                content = {
                  format = "vfat";
                  mountpoint = "/boot";
                  type = "filesystem";

                  mountOptions = [
                    "defaults"
                    "umask=0077"
                  ];
                };
              };

              luks = {
                size = "100%";

                content = {
                  name = "crypted";
                  passwordFile = passwordFile;
                  settings.allowDiscards = true;
                  type = "luks";

                  content = {
                    type = "zfs";
                    pool = "zroot";
                  };
                };
              };
            };
          };
        };

        zpool = {
          zroot = {
            type = "zpool";

            rootFsOptions = {
              canmount = "off";
              checksum = "edonr";
              compression = "zstd";
              "com.sun:auto-snapshot" = "false";
              dnodesize = "auto";
              mountpoint = "none";
              normalization = "formD";
              relatime = "on";
            };

            options = {
              ashift = "12";
              autotrim = "on";
            };

            datasets = {
              reserved = {
                type = "zfs_fs";

                options = {
                  canmount = "off";
                  mountpoint = "none";
                  reservation = "${toString (builtins.ceil (diskSize * 0.05))}G";
                };
              };
            }
            // {
              root = {
                mountpoint = "/";
                type = "zfs_fs";

                options = {
                  "com.sun:auto-snapshot" = "false";
                  mountpoint = "legacy";
                };

                postCreateHook = ''
                  zfs snapshot zroot/root@empty
                '';
              };

              nix = {
                mountpoint = "/nix";
                postCreateHook = "zfs snapshot zroot/nix@empty";
                type = "zfs_fs";

                options = {
                  atime = "off";
                  canmount = "on";
                  "com.sun:auto-snapshot" = "false";
                  mountpoint = "legacy";
                };
              };

              persist = {
                mountpoint = "/persist";
                postCreateHook = "zfs set com.sun:auto-snapshot=false zroot/persist";
                type = "zfs_fs";

                options = {
                  "com.sun:auto-snapshot" = "false";
                  mountpoint = "legacy";
                };
              };
            };
          };
        };
      };

    mkHost =
      {
        extraOptions ? { },
        name,
        withModules ? [ ],
      }:
      let
        facterPath = inputs.self + "/modules/hosts/${name}/facter.json";
        facterReport =
          assert lib.asserts.assertMsg (lib.pathExists facterPath)
            "Facter report not found at ${facterPath} for host ${name}";
          lib.importJSON facterPath;
        hostSystem = facterReport.system;
      in
      inputs.nixpkgs.lib.nixosSystem {
        modules = withModules ++ [
          inputs.self.nixosModules.overlays
          extraOptions
          {
            networking.hostName = lib.mkDefault name;
            nixpkgs.hostPlatform = lib.mkDefault hostSystem;
            system.stateVersion = "26.05";
          }
        ];
      };

    mkUser =
      {
        extraGroups ? [ ],
        extraHomeConfig ? { },
        extraUserOptions ? { },
        hashedPasswordFile ? null,
        userSecrets ? { },
        userSecretsFile ? null,
        username,
        withModules ? [ ],
      }:
      {
        config,
        pkgs,
        ...
      }:
      {
        programs.fish.enable = true;

        home-manager.users.${username} = {
          home.stateVersion = "26.05";
          imports = withModules;
        }
        // extraHomeConfig;

        # Ensure persistent home directory exists for preservation
        systemd.tmpfiles.rules = [
          "d /persist/home/${username} 0700 ${username} users -"
        ];

        # Configure user-specific sops secrets
        sops.secrets = lib.mkIf (userSecretsFile != null) (
          lib.mapAttrs (
            _name: secretConfig:
            {
              sopsFile = userSecretsFile;
              owner = username;
              group = "users";
            }
            // secretConfig
          ) userSecrets
        );

        users.users.${username} = {
          extraGroups = [ "wheel" ] ++ extraGroups;
          isNormalUser = true;
          shell = pkgs.fish;
        }
        // (
          # Use hashedPasswordFile if provided, otherwise use user_password from userSecrets
          if hashedPasswordFile != null then
            { hashedPasswordFile = hashedPasswordFile; }
          else if (userSecrets ? user_password) then
            { hashedPasswordFile = config.sops.secrets.user_password.path; }
          else
            { }
        )
        // extraUserOptions;
      };
  };
}
