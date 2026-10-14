{
  flake.nixosModules.shell = {
    config = {
      programs.fish.enable = true;

      home-manager.sharedModules = [
        {
          programs = {
            fish = {
              enable = true;

              # switch/boot activate a real generation, so they should only
              # ever run on described, committed code. build/test are for
              # iterating on dirty working-copy state.
              functions.check-clean = ''
                if not command -q jj
                  echo "jj is not installed, so uncommitted changes can't be ruled out." >&2
                  return 1
                end
                if jj log -r '@ & ~empty()' --no-graph -T 'change_id' 2>/dev/null | string length -q
                  echo "Working copy has uncommitted changes. Describe them first." >&2
                  return 1
                end
              '';

              # Rebuilds want the YubiKey in. Activation doesn't need it
              # (sops-nix decrypts with the host's own age key); the check is
              # by choice, so the key is at hand whenever the system changes.
              # Only for the local host: ndeploy activates remotely.
              functions.check-yubikey = ''
                if test (age-plugin-yubikey --list 2>/dev/null | count) -eq 0
                  echo "YubiKey not detected. Plug it in before rebuilding." >&2
                  return 1
                end
              '';

              functions.ndeploy = ''
                if test (count $argv) -eq 0
                  echo "Usage: ndeploy <hostname> [switch|boot]"
                  return 1
                end
                check-clean; or return 1
                set -l action switch
                if test (count $argv) -ge 2
                  switch $argv[2]
                    case switch boot
                      set action $argv[2]
                    case '*'
                      echo "Invalid action: $argv[2] (must be switch or boot)"
                      return 1
                  end
                end
                # --use-substitutes lets the target pull cached paths from
                # cache.nixos.org directly instead of forcing the full closure
                # over the SSH/tailscale link. nh asks for the remote sudo
                # password itself, whatever its elevation strategy, but sudo
                # on dapple tries a YubiKey touch first (ssh-server.nix): at
                # the prompt, any character (nh refuses an empty one) and a
                # touch will do.
                nh os $action /etc/nixos --hostname $argv[1] --target-host nixos@$argv[1] --use-substitutes --no-nom
              '';

              functions.nrun = ''
                nix run nixpkgs#$argv[1] -- $argv[2..]
              '';

              interactiveShellInit = builtins.concatStringsSep "\n" [
                "set -g fish_greeting"
                ''
                  function nshell
                    nix-shell -p $argv --command fish
                  end
                ''
                # Autosuggestions (the inline grey completion while typing) are
                # drawn from the active history session, so giving each
                # directory its own session is what scopes them to that
                # directory. Search stays global, see fzf-history-global.
                ''
                  function __history_per_directory --on-variable PWD
                    set -g fish_history (string replace -ra '[^A-Za-z0-9]' _ -- $PWD)
                  end
                  __history_per_directory
                ''
                # fzf's own ctrl-r widget shells out to `builtin history` in a
                # child fish, which only ever sees the default session and so
                # goes blind once history is split per directory. Read every
                # session file directly instead, ordered newest first by each
                # entry's `when:` timestamp (a plain `tac` over the
                # concatenation only reverses within each file), deduplicated.
                ''
                  function fzf-history-global --description "Search command history from every directory"
                    set -l query (commandline | string collect)
                    set -l selected (awk '/^- cmd: /{cmd=substr($0, 8)} /^ +when: /{print $2, cmd}' $__fish_user_data_dir/*_history 2>/dev/null | sort -rns | cut -d' ' -f2- | awk '$0 != "exit" && !seen[$0]++' | fzf --scheme=history --height=40% --layout=default --query "$query")
                    if test -n "$selected"
                      commandline -r -- $selected
                    end
                    commandline -f repaint
                  end

                  bind ctrl-r fzf-history-global
                  bind up fzf-history-global
                ''
              ];

              shellAliases = {
                # General
                "c" = "clear";

                # Nix
                "nboot" =
                  "check-yubikey; and check-clean; and nh os boot /etc/nixos --hostname (hostname) --no-nom";
                "nbuild" = "nh os build /etc/nixos --hostname (hostname) --no-nom";
                "ncheck" = "nix flake check /etc/nixos";
                "nformat" = "pushd /etc/nixos && sudo nix fmt . && popd";
                "nlist" = "sudo nixos-rebuild list-generations";
                "nrollback" = "nh os rollback";
                "nsearch" = "nh search";
                "nswitch" =
                  "check-yubikey; and check-clean; and nh os switch /etc/nixos --hostname (hostname) --no-nom";
                "ntest" = "check-yubikey; and nh os test /etc/nixos --hostname (hostname) --no-nom";
                "nupdate" = "pushd /etc/nixos && nix flake update && popd";
              };
            };

            fzf = {
              enable = true;
              enableFishIntegration = true;
            };
          };
        }

        (
          { lib, pkgs, ... }:
          let
            jj-starship = lib.getExe pkgs.jj-starship;
          in
          {
            # The prompt, in the terminal's ANSI colors. jj-starship shows
            # the jj change (or the git branch, outside jj) in place of
            # starship's own git modules, which would show git twice.
            programs.starship = {
              enable = true;

              settings = {
                git_branch.disabled = true;
                git_commit.disabled = true;
                git_status.disabled = true;

                custom.jj = {
                  format = "$output ";
                  shell = [ jj-starship ];
                  when = "${jj-starship} detect";
                };
              };
            };
          }
        )
      ];

      my.preservation.homeDirectories = [
        ".local/share/fish"
      ];
    };
  };
}
