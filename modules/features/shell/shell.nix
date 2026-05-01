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
                "zoxide init fish | source"
              ];

              functions.ndeploy = ''
                if test (count $argv) -eq 0
                  echo "Usage: ndeploy <hostname> [switch|boot]"
                  return 1
                end
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
                "nboot" = "nh os boot /etc/nixos --hostname (hostname) --no-nom";
                "nbuild" = "nh os build /etc/nixos --hostname (hostname) --no-nom";
                "ncheck" = "pushd /etc/nixos && nixos-rebuild check --flake .#(hostname) --no-reexec && popd";
                "nformat" = "pushd /etc/nixos && nix fmt . && popd";
                "nlist" = "sudo nixos-rebuild list-generations";
                "nrollback" = "nh os rollback";
                "nsearch" = "nh search";
                "nswitch" = "nh os switch /etc/nixos --hostname (hostname) --no-nom";
                "ntest" = "nh os test /etc/nixos --hostname (hostname) --no-nom";
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
