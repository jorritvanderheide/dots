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
      cfg = config.settings.ssh-server;

      # Collect authorized keys from all home-manager users
      collectAuthorizedKeys = lib.mapAttrs (
        _username: userCfg:
        lib.optionalAttrs (userCfg.settings.ssh-server ? authorizedKeys) {
          openssh.authorizedKeys.keys = userCfg.settings.ssh-server.authorizedKeys;
        }
      ) config.home-manager.users;
    in
    {
      options.settings.ssh-server = {
        enable = lib.mkEnableOption "OpenSSH server";

        allowedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Users permitted to connect via SSH";
        };
      };

      config = lib.mkIf cfg.enable {
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
        settings.preservation.systemFiles = [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        # Apply authorized keys from home-manager user configs
        users.users = collectAuthorizedKeys;

        # Home-manager module for per-user SSH key configuration
        home-manager.sharedModules = [
          {
            options.settings.ssh-server = {
              authorizedKeys = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Authorized SSH public keys for remote login";
              };
            };
          }
        ];

      };
    };
}
