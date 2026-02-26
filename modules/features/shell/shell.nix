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
                  "nboot" = "pushd /etc/nixos && sudo nixos-rebuild boot --flake .#(hostname) --no-reexec && popd";
                  "nbuild" = "pushd /etc/nixos && sudo nixos-rebuild build --flake .#(hostname) --no-reexec && popd";
                  "ncheck" = "pushd /etc/nixos && nix flake check && popd";
                  "nclean" = "nix-collect-garbage -d";
                  "nformat" = "pushd /etc/nixos && nix fmt . && popd";
                  "nrollback" = "sudo nixos-rebuild switch --no-reexec --rollback";
                  "nswitch" =
                    "pushd /etc/nixos && sudo nixos-rebuild switch --flake .#(hostname) --no-reexec && popd";
                  "ntest" = "pushd /etc/nixos && sudo nixos-rebuild test --flake .#(hostname) --no-reexec && popd";
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
