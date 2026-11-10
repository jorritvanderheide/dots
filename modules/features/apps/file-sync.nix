{
  inputs,
  ...
}:
{
  # ~/Documents, synced with dapple's copy (syncthing.nix) over the
  # tailnet, and the Obsidian vault, whose home and git history are on
  # dapple (vault.nix), and nothing else: no discovery, relays or other
  # traffic to Syncthing's servers, and listening on loopback only, since
  # rocinante dials dapple. Its web interface is at http://127.0.0.1:8384.
  flake.nixosModules.file-sync =
    { config, ... }:
    let
      inherit (inputs.self.lib) site;

      # research comes with the desktop bundle. Resolved out here because
      # the home-manager module rebinds `config`.
      inherit (config.my.research) vaultPath;
    in
    {
      config = {
        home-manager.sharedModules = [
          (
            { config, osConfig, ... }:
            {
              # What stays on this laptop: Obsidian's window state, the
              # snippet the theme writes (theming/obsidian.nix), Claude's
              # sessions and Obsidian's trash. And .git, which only dapple
              # has.
              home.file."${vaultPath}/.stignore".text = ''
                .git
                /.claude
                /.claudian/sessions
                /.obsidian/snippets/noctalia.css
                /.obsidian/workspace*.json
                /.trash
              '';

              # ~/Documents is a filesystem of its own, so what's deleted
              # there goes to a trash folder inside it, which would sync.
              home.file."Documents/.stignore".text = ''
                .Trash-*
              '';

              services.syncthing = {
                enable = true;
                cert = osConfig.sops.secrets.syncthing_cert.path;
                key = osConfig.sops.secrets.syncthing_key.path;

                settings = {
                  devices.dapple = {
                    addresses = [ "tcp://${site.hosts.dapple.tailnetIp}:${toString site.syncthing.port}" ];
                    id = site.syncthing.devices.dapple;
                  };

                  folders.documents = {
                    devices = [ "dapple" ];
                    path = "${config.home.homeDirectory}/Documents";
                  };

                  folders.obsidian = {
                    devices = [ "dapple" ];
                    path = "${config.home.homeDirectory}/${vaultPath}";
                  };

                  options = {
                    crashReportingEnabled = false;
                    globalAnnounceEnabled = false;
                    listenAddresses = [ "tcp://127.0.0.1:${toString site.syncthing.port}" ];
                    localAnnounceEnabled = false;
                    natEnabled = false;
                    relaysEnabled = false;
                    urAccepted = -1;
                  };
                };
              };
            }
          )
        ];

        # The index. The files are in ~/Documents, which preservation keeps
        # for every user.
        my.preservation.homeDirectories = [
          ".local/state/syncthing"
        ];

        # The identity dapple knows this laptop by (site.syncthing.devices),
        # so a reinstall syncs again without a new device ID: Syncthing's
        # cert.pem and key.pem, which it copies in at each start. They are
        # yours, as the user service copies them.
        sops.secrets = {
          syncthing_cert.owner = site.user;
          syncthing_key.owner = site.user;
        };
      };
    };
}
