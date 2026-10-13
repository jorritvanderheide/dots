# Bazarr, which fetches subtitles for Sonarr's and Radarr's libraries. The
# rest of the stack is in default.nix.
{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.servarr =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.servarr;
      subdomain = "bazarr";
      port = 6767;
      libraryDir = "${config.my.media-library.dir}/library";
    in
    {
      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;

            status = {
              group = "media";
              name = "bazarr";
            };
          })
          {
            sops.secrets.bazarr_password.restartUnits = [ "bazarr.service" ];
            users.users.bazarr.extraGroups = [ "media" ];

            my.offsite-backup.entries.servarr = {
              exclude = [ "/var/lib/bazarr/log" ];
              paths = [ "/var/lib/bazarr" ];
              units = [ "bazarr.service" ];
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/bazarr";
                group = "bazarr";
                mode = "0700";
                user = "bazarr";
              }
            ];

            # Writes .srt files next to the media, so Jellyfin auto-detects
            # them. Its own defaults are every interface and no login, and
            # then its page hands out the API key, which unlocks Sonarr's and
            # Radarr's too.
            services.bazarr = {
              enable = true;
              openFirewall = false;

              settings = {
                auth = {
                  # The password's md5 hex digest, which is what Bazarr compares.
                  password._secret = config.sops.secrets.bazarr_password.path;

                  type = "form";
                  username = cfg.webuiUser;
                };

                general = {
                  inherit port;
                  ip = "127.0.0.1";
                };
              };
            };

            systemd.services.bazarr.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";

              # Repair folders created before sonarr's and radarr's UMask (or by other
              # means). "+" runs it as root. -h so that a folder swapped
              # for a symlink in the meantime (the media group can write
              # here) doesn't hand root's chmod to whatever it points at.
              ExecStartPre = [
                "+${pkgs.findutils}/bin/find ${libraryDir}/series ${libraryDir}/movies -type d ! -perm -g+w -exec chmod -h g+w {} +"
              ];
            };
          }
        ]
      );
    };
}
