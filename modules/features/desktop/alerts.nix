{
  inputs,
  lib,
  ...
}:
{
  # The status page's alerts (gatus.nix) as notifications on the desktop
  # too, not only on the phone: a subscription to the same ntfy topic
  # (ntfy.nix), over the tailnet, where ntfy answers. With a token of this
  # host's own, ntfy_token, which dapple knows as ntfy_token_rocinante, so a
  # stolen laptop's can be revoked alone.
  flake.nixosModules.alerts =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (inputs.self.lib) site;
    in
    {
      config = {
        sops.secrets.ntfy_token = { };

        # The token stays out of ntfy's arguments, which any local user can
        # read. ntfy runs the command with sh for each message; the topic is
        # my.ntfy.topic's default (ntfy.nix).
        sops.templates."ntfy-client.yml" = {
          owner = site.user;

          content = ''
            default-host: https://alerts.${site.domain}
            default-token: ${config.sops.placeholder.ntfy_token}
            subscribe:
              - topic: alerts
                command: 'notify-send --app-name=Status "$NTFY_TITLE" "$NTFY_MESSAGE"'
          '';
        };

        home-manager.users.${site.user}.systemd.user.services.ntfy-alerts = {
          Install.WantedBy = [ "graphical-session.target" ];

          Unit = {
            Description = "The status page's alerts, as desktop notifications";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          # It reconnects by itself while the tailnet is away; Restart is for
          # when it gives up.
          Service = {
            Environment = "PATH=${lib.makeBinPath [ pkgs.libnotify ]}:/run/current-system/sw/bin";
            ExecStart = "${lib.getExe' pkgs.ntfy-sh "ntfy"} subscribe --config ${config.sops.templates."ntfy-client.yml".path} --from-config";
            Restart = "always";
            RestartSec = "30s";
          };
        };
      };
    };
}
