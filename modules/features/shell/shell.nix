{
  flake.nixosModules.shell = {
    config = {
      programs.fish.enable = true;

      my.preservation.homeDirectories = [
        ".local/share/fish"
      ];

      home-manager.sharedModules = [
        {
          programs = {
            fish = {
              enable = true;

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
                # session file directly instead, newest first, deduplicated.
                ''
                  function fzf-history-global --description "Search command history from every directory"
                    set -l query (commandline | string collect)
                    set -l selected (cat $__fish_user_data_dir/*_history 2>/dev/null | string match -rg '^- cmd: (.*)' | tac | awk '!seen[$0]++' | fzf --scheme=history --height=40% --reverse --query "$query")
                    if test -n "$selected"
                      commandline -r -- $selected
                    end
                    commandline -f repaint
                  end

                  bind ctrl-r fzf-history-global
                  bind up fzf-history-global
                ''
                "zoxide init fish | source"
              ];

              # Activation (boot/switch/test) restarts the sops-secret
              # services (see mkSopsService), which need the YubiKey present
              # to decrypt -- without it they retry for up to 5 minutes
              # before nixos-rebuild reports the failure. Catch that upfront
              # instead. Only meaningful for the local host: ndeploy activates
              # remotely, where this machine's YubiKey state is irrelevant.
              functions.check-yubikey = ''
                if test (age-plugin-yubikey --list 2>/dev/null | count) -eq 0
                  echo "YubiKey not detected -- plug it in before rebuilding (needed to decrypt secrets during activation)." >&2
                  return 1
                end
              '';

              # switch/boot activate a real generation, so they should only
              # ever run on described, committed code. build/test are for
              # iterating on dirty working-copy state.
              functions.check-clean = ''
                if jj log -r '@ & ~empty()' --no-graph -T 'change_id' 2>/dev/null | string length -q
                  echo "Working copy has uncommitted changes -- describe them first (nswitch/nboot/ndeploy require a clean working copy; use nbuild/ntest to iterate on dirty code)." >&2
                  return 1
                end
              '';

              functions.nrun = ''
                nix run nixpkgs#$argv
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
                # over the SSH/tailscale link.
                # --ask-sudo-password prompts locally for the remote sudo password
                # (target hosts require it since wheelNeedsPassword=true).
                nixos-rebuild $action --flake /etc/nixos#$argv[1] --target-host nixos@$argv[1] --sudo --ask-sudo-password --use-substitutes
              '';

              shellAliases = {
                # General
                "c" = "clear";

                # Nix
                "nboot" =
                  "check-yubikey; and check-clean; and nh os boot /etc/nixos --hostname (hostname) --no-nom";
                "nbuild" = "nh os build /etc/nixos --hostname (hostname) --no-nom";
                "ncheck" = "pushd /etc/nixos && nixos-rebuild check --flake .#(hostname) --no-reexec && popd";
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
      ];
    };
  };
}
