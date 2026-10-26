{
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
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

        # So SSH sessions from Ghostty render correctly.
        environment.systemPackages = [ pkgs.ghostty.terminfo ];

        # By source address, not just by interface: the router's port
        # forward arrives on the LAN interface too.
        networking.firewall.extraInputRules = lib.mkIf cfg.lanAccess.enable ''
          iifname "${config.my.lan.interface}" ip saddr ${config.my.lan.subnet} tcp dport 22 accept
        '';

        # A trusted nix user can add unsigned store paths and set root-run
        # build hooks, which makes it root without sudo's password. So only
        # root.
        nix.settings.trusted-users = lib.mkForce [ "root" ];

        services.openssh = {
          enable = true;
          allowSFTP = false;

          # Only the keys declared here: ~/.ssh outlives the root wipe, so a
          # key planted there would too.
          authorizedKeysInHomedir = false;

          extraConfig = ''
            AllowAgentForwarding no
            AllowStreamLocalForwarding no
            AllowTcpForwarding no
            AuthenticationMethods publickey
            X11Forwarding no
          '';

          hostKeys = [
            {
              inherit (config.sops.secrets.ssh_host_key) path;
              type = "ed25519";
            }
          ];

          # Not on every interface: the tailnet here, and the home LAN with
          # lanAccess.
          openFirewall = false;

          settings = {
            AllowUsers = cfg.allowedUsers;
            KbdInteractiveAuthentication = false;
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        # The host key is a secret, not a file on /persist, so a reinstalled
        # host has the key the others pin (lib.site) from its first boot.
        sops.secrets.ssh_host_key.restartUnits = [ "sshd.service" ];
      };
    };
}
