{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.emacs =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Doom writes its runtime state (recentf, savehist, projectile cache,
        # etc.) to DOOMLOCALDIR. Packages and native-compiled .eln live in the
        # nix store, so only this state dir needs to survive a reboot.
        my.preservation.homeDirectories = [
          ".local/share/nix-doom"
        ];

        home-manager.sharedModules = [
          inputs.nix-doom-emacs-unstraightened.homeModule
          (
            { config, ... }:
            {
              programs.doom-emacs = {
                enable = true;

                # Only the doom config itself, so editing emacs.nix (which lives
                # in this same directory) doesn't rebuild Doom.
                doomDir = lib.fileset.toSource {
                  root = ./.;
                  fileset = lib.fileset.unions [
                    ./init.el
                    ./config.el
                    ./packages.el
                  ];
                };

                # doomLocalDir must be an absolute path (no ~ expansion).
                doomLocalDir = "${config.home.homeDirectory}/.local/share/nix-doom";

                # pgtk build: native Wayland rendering under niri.
                emacs = pkgs.emacs-pgtk;
              };
            }
          )
        ];
      };
    };
}
