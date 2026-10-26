{
  inputs,
  ...
}:
{
  # Deploys what's pushed to Codeberg: comin polls the repository, builds
  # this host's configuration from the newest commit on main signed by a
  # key in lib.commitSigners, and switches to it. A testing-<host> branch
  # on top of main goes first, with `test`, which a reboot undoes. The
  # signature is what takes a YubiKey: commits are signed as they are
  # pushed, with the PIV key on one (git.nix).
  flake.nixosModules.comin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      url = "${inputs.self.lib.site.statusPage}/api/v1/endpoints/deploys_${config.networking.hostName}/external";

      # On a desktop, also a notification in the person's session, through
      # their systemd user manager: comin's own desktop client would need
      # its control socket, which is root's alone (below). Skipped when
      # nobody is logged in.
      notify = lib.optionalString config.services.graphical-desktop.enable ''
        commit="''${COMIN_GIT_SHA:0:12}: ''${COMIN_GIT_MSG%%$'\n'*}"
        if [[ -n "$COMIN_ERROR_MSG" || "$COMIN_STATUS" == failed ]]; then
          urgency=critical title="Deploy: $COMIN_PHASE failed" body="$commit"$'\n'"''${COMIN_ERROR_MSG:0:300}"
        elif [[ "$COMIN_PHASE" == deploy ]]; then
          urgency=normal title="Deployed" body="$commit"
        fi
        if [[ -v title ]]; then
          systemd-run --machine=${inputs.self.lib.site.user}@.host --user --quiet --collect \
            ${lib.getExe' pkgs.libnotify "notify-send"} --app-name=comin --urgency="$urgency" "$title" "$body" || true
        fi
      '';

      # Run after each build and each deployment: a failure of either, or a
      # deployment that worked, goes to the status page (gatus.nix) as
      # deploys/<host>, and in the notification. A build that worked is told
      # by the deployment after it. An evaluation that fails runs neither;
      # `sudo comin status` shows it.
      report = pkgs.writeShellApplication {
        name = "comin-report";

        runtimeInputs = [
          pkgs.curl
          pkgs.systemd
        ];

        # The header on stdin, not in curl's arguments, which any local
        # user can read.
        text = ''
          ${notify}
          if [[ -n "$COMIN_ERROR_MSG" || "$COMIN_STATUS" == failed ]]; then
            query=(--data-urlencode success=false --data-urlencode "error=$COMIN_PHASE of ''${COMIN_GIT_SHA:0:12} failed: ''${COMIN_ERROR_MSG:0:300}")
          elif [[ "$COMIN_PHASE" == deploy ]]; then
            query=(--data-urlencode success=true)
          else
            exit 0
          fi

          TOKEN="$(<${config.sops.secrets.gatus_push_token.path})"
          curl -X POST -G -fsS -o /dev/null --retry 3 --retry-all-errors --retry-delay 10 --config - ${lib.escapeShellArg url} "''${query[@]}" <<<"header = \"Authorization: Bearer $TOKEN\""
        '';
      };
    in
    {
      imports = [ inputs.comin.nixosModules.comin ];

      config = {
        sops.secrets.gatus_push_token = { };

        # Its clone, and the main it saw last, which a newer main has to be
        # on top of. After a force push to main it deploys nothing until
        # this is emptied, which also forgets that. Root's alone: comin
        # makes its control socket writable by everyone, and through it any
        # local user, a CI job too, could suspend it for good.
        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/comin";
            mode = "0700";
          }
        ];

        services.comin = {
          enable = true;
          postBuildCommand = lib.getExe report;
          postDeploymentCommand = lib.getExe report;
          sshAllowedSignersPath = "${pkgs.writeText "comin-allowed-signers" (
            lib.concatLines inputs.self.lib.commitSigners
          )}";

          # Its Prometheus metrics, which nothing here scrapes.
          exporter.listen_address = "127.0.0.1";

          remotes = [
            {
              name = "codeberg";
              url = "https://codeberg.org/BW20/dots.git";
            }
          ];
        };
      };
    };
}
