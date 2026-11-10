{
  inputs,
  ...
}:
{
  # The Obsidian vault's home: Syncthing keeps it in step with rocinante's
  # (file-sync.nix), and dapple alone keeps its git history, committing
  # what changed every 15 minutes and pushing it to Codeberg. rocinante's
  # copy has no .git, so nothing else pushes there; a push that fails
  # because something did fails the unit, which unit-health reports. Its
  # first run makes the repository from Codeberg's, over the files already
  # there, so it doesn't matter whether Syncthing or the timer comes first.
  #
  # Nothing over 5 MB is committed, the vault's own rule (its CLAUDE.md):
  # history is for good, so recordings and video stay outside it, linked.
  # Such a file fails the unit, and so blocks every commit until it's
  # moved out.
  flake.nixosModules.vault =
    {
      config,
      pkgs,
      ...
    }:
    let
      vault = "${config.services.syncthing.dataDir}/obsidian";

      # ssh-keyscan -t ed25519 codeberg.org, on 2026-10-27.
      knownHosts = pkgs.writeText "codeberg-known-hosts" ''
        codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB
      '';
    in
    {
      config = {
        assertions = [
          {
            assertion = config.services.syncthing.enable;
            message = "vault needs the syncthing feature";
          }
        ];

        # It works in Syncthing's files, as Syncthing's user, and a restore
        # stops if something still has them open.
        my.offsite-backup.entries.syncthing.units = [ "vault-commit.service" ];

        # Its .git stays here: rocinante's copy is only the files.
        services.syncthing.settings.folders.obsidian = {
          devices = [ "rocinante" ];
          ignorePatterns = [ ".git" ];
          path = vault;
        };

        # A write-access deploy key on BW20/obsidian.
        sops.secrets.obsidian_deploy_key.owner = "syncthing";

        systemd.services.vault-commit = {
          description = "Commit the Obsidian vault and push it to Codeberg";

          environment = {
            GIT_AUTHOR_EMAIL = "root@dapple";
            GIT_AUTHOR_NAME = "dapple";
            GIT_COMMITTER_EMAIL = "root@dapple";
            GIT_COMMITTER_NAME = "dapple";
            GIT_SSH_COMMAND = "ssh -i ${config.sops.secrets.obsidian_deploy_key.path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${knownHosts}";
          };

          path = [
            pkgs.git
            pkgs.openssh
          ];

          # Pushes only what Codeberg doesn't have yet, so a quiet vault
          # costs no connection, and a failed push is tried again next run.
          script = ''
            cd ${vault}
            if [[ ! -d .git ]]; then
              git init --quiet --initial-branch=main
              git remote add origin ssh://git@codeberg.org/BW20/obsidian.git
              git fetch --quiet origin main
              git reset --quiet origin/main
              git branch --quiet --set-upstream-to=origin/main
            fi
            git add --all
            too_big=0
            while IFS= read -r -d "" file; do
              if (( $(git cat-file -s ":$file") > 5 * 1024 * 1024 )); then
                echo "Over 5 MB, move it out of the vault: $file" >&2
                too_big=1
              fi
            done < <(git diff --cached --name-only --diff-filter=ACM -z)
            if (( too_big )); then
              exit 1
            fi
            if ! git diff --cached --quiet; then
              git commit --quiet --message "vault backup: $(date '+%Y-%m-%d %H:%M:%S')"
            fi
            if [[ -n $(git rev-list origin/main..main) ]]; then
              git push --quiet origin main
            fi
          '';

          serviceConfig = inputs.self.lib.sandbox // {
            Group = "syncthing";
            ProtectSystem = "strict";
            ReadWritePaths = [ vault ];
            Type = "oneshot";
            UMask = "0077";
            User = "syncthing";
          };
        };

        systemd.timers.vault-commit = {
          timerConfig.OnCalendar = "*:0/15";
          wantedBy = [ "timers.target" ];
        };
      };
    };
}
