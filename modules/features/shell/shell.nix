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

              functions.nrun = ''
                nix run nixpkgs#$argv
              '';

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
                "nboot" = "check-yubikey; and nh os boot /etc/nixos --hostname (hostname) --no-nom";
                "nbuild" = "nh os build /etc/nixos --hostname (hostname) --no-nom";
                "ncheck" = "pushd /etc/nixos && nixos-rebuild check --flake .#(hostname) --no-reexec && popd";
                "nformat" = "pushd /etc/nixos && sudo nix fmt . && popd";
                "nlist" = "sudo nixos-rebuild list-generations";
                "nrollback" = "nh os rollback";
                "nsearch" = "nh search";
                "nswitch" = "check-yubikey; and nh os switch /etc/nixos --hostname (hostname) --no-nom";
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
