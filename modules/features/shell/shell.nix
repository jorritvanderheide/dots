{
  lib,
  ...
}:
{
  flake.nixosModules.shell =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.shell;
    in
    {
      options.settings.shell = {
        enable = lib.mkEnableOption "Fish shell";
      };

      config = lib.mkIf cfg.enable {
        programs.fish.enable = true;

        settings.preservation.homeDirectories = [
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

                shellAliases = {
                  # General
                  "c" = "clear";

                  # Nix
                  "nboot" = "nh os boot /etc/nixos#(hostname) --no-nom";
                  "nbuild" = "nh os build /etc/nixos#(hostname) --no-nom";
                  "ncheck" = "pushd /etc/nixos && nixos-rebuild check --flake .#(hostname) --no-reexec && popd";
                  "nclean" = "nh clean all -k 16 --ask";
                  "nformat" = "pushd /etc/nixos && nix fmt . && popd";
                  "nrollback" = "nh os rollback";
                  "nsearch" = "nh search";
                  "nswitch" = "nh os switch /etc/nixos#(hostname) --no-nom";
                  "ntest" = "nh os test /etc/nixos#(hostname) --no-nom";
                  "nupdate" = "pushd /etc/nixos && sudo nix flake update && popd";
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
