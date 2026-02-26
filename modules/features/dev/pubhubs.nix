{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.pubhubs =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.pubhubs;
    in
    {
      imports = [ inputs.pubhubs.nixosModules.pubhubs-hub ];

      options.settings.pubhubs = {
        enable = lib.mkEnableOption "PubHubs hub deployment";
      };

      config = lib.mkIf cfg.enable {
        services.pubhubs-hub = {
          enable = false;
          nginx.listenAddress = "0.0.0.0";
          serverName = "localhost";
          publicBaseUrl = "http://localhost:8008";
          clientUrl = "http://localhost:8008";
          globalClientUrl = "http://localhost:8080";
          phcUrl = "http://localhost:5050";
          macaroonSecretKeyFile = "/tmp/pubhubs-macaroon";
          # macaroonSecretKeyFile = config.sops.secrets.pubhubs-macaroon.path;
        };

        # sops.secrets.pubhubs-macaroon = { };

        # Persist hub state across reboots
        settings.preservation.systemDirectories = [
          "/var/lib/pubhubs-hub"
        ];
      };
    };
}
