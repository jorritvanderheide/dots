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
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

        # Preserve state
        my.preservation.systemFiles = [
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        services.openssh = {
          enable = true;
          allowSFTP = false;

          # Only the keys declared here: ~/.ssh outlives the root wipe, so a
          # key planted there would too.
          authorizedKeysInHomedir = false;

          # Not on every interface: the tailnet here, and the host adds its
          # LAN if it wants it.
          openFirewall = false;

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
      };
    };
}
