{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.ssh-server =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.ssh-server;
    in
    {
      options.my.ssh-server = {
        lanAccess.enable = lib.mkEnableOption "SSH from the home LAN's subnet (my.lan), besides the tailnet";

        allowedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Users permitted to connect via SSH";
        };
      };

      config = {
        # sudo over SSH takes a touch of a YubiKey on the machine you came
        # from: one of lib.sudoKeys, in the agent forwarded for it, signs
        # pam_rssh's challenge. Not the login keys, which stay in Bitwarden's
        # agent. Without that agent (or a touch), the password.
        environment.etc."ssh/sudo_keys".text = lib.concatLines inputs.self.lib.sudoKeys;

        # So SSH sessions from Ghostty render correctly.
        environment.systemPackages = [ pkgs.ghostty.terminfo ];

        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
        security.pam.services.sudo.rssh = true;

        # Preserve state
        my.preservation.systemFiles = [
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        # By source address, not just by interface: the router's port
        # forward arrives on the LAN interface too.
        networking.firewall.extraInputRules = lib.mkIf cfg.lanAccess.enable ''
          iifname "${config.my.lan.interface}" ip saddr ${config.my.lan.subnet} tcp dport 22 accept
        '';

        # A host reached over SSH is one `ndeploy` deploys to. A trusted nix
        # user can add unsigned store paths and set root-run build hooks,
        # which makes it root without sudo's password. So only root, and
        # what `ndeploy` copies here must be signed by one of
        # lib.deployKeys instead.
        nix.settings = {
          trusted-public-keys = inputs.self.lib.deployKeys;
          trusted-users = lib.mkForce [ "root" ];
        };

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

          # Not on every interface: the tailnet here, and the home LAN with
          # lanAccess.
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
