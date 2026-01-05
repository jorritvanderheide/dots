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
      cfg = config.features.shell;
    in
    {
      options.features.shell = {
        enable = lib.mkEnableOption "Fish shell";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.shell requires features.impermanence to be enabled";
          }
        ];

        programs.fish.enable = true;

        home-manager.sharedModules = [
          {
            programs = {
              fish = {
                enable = true;

                interactiveShellInit = builtins.concatStringsSep "\n" [
                  ''set -g fish_greeting''
                  ''
                    function nshell
                      nix-shell -p $argv --command fish
                    end
                  ''
                  ''zoxide init fish | source''
                ];
                
                shellAliases = {
                  # General
                  "c" = "clear";

                  # Nix
                  "nboot" = "pushd /persist/etc/nixos && sudo nixos-rebuild boot --flake .#(hostname) --no-reexec && popd";
                  "nbuild" = "pushd /persist/etc/nixos && sudo nixos-rebuild build --flake .#(hostname) --no-reexec && popd";
                  "ncheck" = "pushd /persist/etc/nixos && nix flake check && popd";
                  "nclean" = "nix-collect-garbage -d";
                  "nformat" = "pushd /persist/etc/nixos && nix fmt /persist/etc/nixos && popd";
                  "nrollback" = "sudo nixos-rebuild switch --no-reexec --rollback";
                  "nswitch" = "pushd /persist/etc/nixos && sudo nixos-rebuild switch --flake .#(hostname) --no-reexec && popd";
                  "ntest" = "pushd /persist/etc/nixos && sudo nixos-rebuild test --flake .#(hostname) --no-reexec && popd";
                  "nupdate" = "pushd /etc/nixos && sudo nix flake update && popd";
                };
              };

              fzf = {
                enable = true;
                enableFishIntegration = true;
              };
            };

            features.impermanence.homeDirectories = [
              ".local/share/fish"
            ];
          }
        ];
      };
    };
}
