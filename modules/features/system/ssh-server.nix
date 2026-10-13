{
  inputs,
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
        # sudo over SSH takes a touch of a YubiKey on the machine you came
        # from: one of lib.sudoKeys, in the agent forwarded for it, signs
        # pam_rssh's challenge. Not the login keys, which stay in Bitwarden's
        # agent. Without that agent (or a touch), the password.
        environment.etc."ssh/sudo_keys".text = lib.concatLines inputs.self.lib.sudoKeys;

        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
        security.pam.services.sudo.rssh = true;

        # Preserve state
        my.preservation.systemFiles = [
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        security.pam.rssh = {
          enable = true;

          settings = {
            auth_key_file = "/etc/ssh/sudo_keys";
            cue = true;
          };
        };

        # One touch (or password) for sudo's usual 5 minutes in all of an SSH
        # user's sessions, not per terminal: ndeploy's nh runs each sudo in a
        # session of its own, so a deploy took a touch for each. Only these
        # users run anything as themselves here; every service has its own.
        security.sudo.extraConfig = lib.concatMapStrings (
          user: "Defaults:${user} timestamp_type=global\n"
        ) cfg.allowedUsers;

        services.openssh = {
          enable = true;
          allowSFTP = false;

          # Only the keys declared here: ~/.ssh outlives the root wipe, so a
          # key planted there would too.
          authorizedKeysInHomedir = false;

          # Not on every interface: the tailnet here, and the host adds its
          # LAN if it wants it.
          openFirewall = false;

          # Agent forwarding only for sudo's keys (below): rocinante forwards
          # an agent with nothing else in it.
          extraConfig = ''
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
