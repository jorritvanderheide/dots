# Recyclarr, which keeps Sonarr's and Radarr's quality profiles in line with
# TRaSH-Guides. The rest of the stack is in default.nix.
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
      sonarrApiKeyPath = "/run/secrets/sonarr_api_key";
      radarrApiKeyPath = "/run/secrets/radarr_api_key";
      local = app: "http://127.0.0.1:${toString config.services.${app}.settings.server.port}";
    in
    {
      options.my.servarr.recyclarr.enable = lib.mkEnableOption ''
        Recyclarr daily sync of TRaSH-Guides quality profiles + custom formats
        into Sonarr and Radarr. Requires sops secrets `sonarr_api_key` and
        `radarr_api_key`, obtained from each app's Settings → General after
        first-run setup. Enable only after both apps are reachable.
      '';

      config = lib.mkIf (cfg.enable && cfg.recyclarr.enable) {
        # Recyclarr 8 removed all official `template:` includes; the
        # modern equivalent is guide-backed profiles via `trash_id`,
        # which pull quality profile + custom format scoring directly
        # from TRaSH-Guides. https://recyclarr.dev/wiki/upgrade-guide/v8.0/
        services.recyclarr = {
          enable = true;
          schedule = "daily";

          # Recyclarr 8 requires instance names to be unique across all
          # apps (not just within an app), so use distinct names rather
          # than `main` everywhere.
          configuration = {
            radarr.movies = {
              api_key._secret = radarrApiKeyPath;
              base_url = local "radarr";
              quality_definition.type = "movie";

              quality_profiles = [
                {
                  reset_unmatched_scores.enabled = true;
                  trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
                }
                {
                  reset_unmatched_scores.enabled = true;
                  trash_id = "64fb5f9858489bdac2af690e27c8f42f"; # UHD Bluray + WEB
                }
              ];
            };

            sonarr.series = {
              api_key._secret = sonarrApiKeyPath;
              base_url = local "sonarr";
              quality_definition.type = "series";

              quality_profiles = [
                {
                  reset_unmatched_scores.enabled = true;
                  trash_id = "72dae194fc92bf828f32cde7744e51a1"; # WEB-1080p
                }
                {
                  reset_unmatched_scores.enabled = true;
                  trash_id = "d1498e7d189fbe6c7110ceaabb7473e6"; # WEB-2160p
                }
              ];
            };
          };
        };

        systemd.services.recyclarr = {
          after = [ "recyclarr-secrets.service" ];
          wants = [ "recyclarr-secrets.service" ];
        };

        systemd.services.recyclarr-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt Sonarr/Radarr API keys for recyclarr from sops";
          wantedBy = [ "multi-user.target" ];

          files = {
            ${radarrApiKeyPath}.key = "radarr_api_key";
            ${sonarrApiKeyPath}.key = "sonarr_api_key";
          };
        };
      };
    };
}
