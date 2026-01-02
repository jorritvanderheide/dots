{
  lib,
  ...
}:
{
  flake.nixosModules.ssh-server =
    {
      config,
      ...
    }:
    let
      cfg = config.features.ssh-server;

      # Collect authorized keys from all home-manager users
      collectAuthorizedKeys = lib.mapAttrs (
        _username: userCfg:
        lib.optionalAttrs (userCfg.features.ssh-server ? authorizedKeys) {
          openssh.authorizedKeys.keys = userCfg.features.ssh-server.authorizedKeys;
        }
      ) config.home-manager.users;
    in
    {
      options.features.ssh-server = {
        enable = lib.mkEnableOption "SSH server";

        allowedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Users allowed to SSH into this system";
        };
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.ssh0server requires features.impermanence to be enabled";
          }
        ];

        services.openssh = {
          enable = true;
          allowSFTP = false;

          extraConfig = ''
            AllowAgentForwarding no
            AllowStreamLocalForwarding no
            AllowTcpForwarding no
            AuthenticationMethods publickey
            X11Forwarding no
          '';

          hostKeys = [
            {
              path = "/persist/system/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];

          settings = {
            AllowUsers = cfg.allowedUsers;
            KbdInteractiveAuthentication = false;
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        # Persist SSH host keys
        features.impermanence.systemFiles = [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        # Apply authorized keys from home-manager user configs
        users.users = collectAuthorizedKeys;

        # Home-manager module for per-user SSH key configuration
        home-manager.sharedModules = [
          {
            options.features.ssh-server = {
              authorizedKeys = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Authorized SSH public keys for this user";
                example = [ "ssh-ed25519 AAAAC3Nza... user@host" ];
              };
            };
          }
        ];

      };
    };
}
