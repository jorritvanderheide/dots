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
      cfg = config.my.ssh-server;

      # Collect authorized keys from all home-manager users
      collectAuthorizedKeys = lib.mapAttrs (
        _username: userCfg:
        lib.optionalAttrs (userCfg.my.ssh-server ? authorizedKeys) {
          openssh.authorizedKeys.keys = userCfg.my.ssh-server.authorizedKeys;
        }
      ) config.home-manager.users;
    in
    {
      options.my.ssh-server = {
        enable = lib.mkEnableOption "OpenSSH server (opens port 22, hardened to pubkey-only)";

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

        # Apply authorized keys from home-manager user configs
        users.users = collectAuthorizedKeys;

        # Preserve state
        my.preservation.systemFiles = [
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        # Home-manager
        home-manager.sharedModules = [
          {
            options.my.ssh-server = {
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
