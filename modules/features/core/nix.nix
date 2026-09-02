{
  inputs,
  ...
}:
{
  flake.nixosModules.nix = {
    config = {
      nixpkgs.config.allowUnfree = true;

      nix = {
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

        # Yields to interactive work under contention, full speed when idle --
        # preferable to capping max-jobs/cores, which slows builds always.
        daemonCPUSchedPolicy = "batch";
        daemonIOSchedClass = "best-effort";
        daemonIOSchedPriority = 7;

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
          persistent = true;
        };

        settings = {
          allowed-users = [ "@wheel" ];
          auto-optimise-store = true;
          keep-derivations = true;
          keep-outputs = true;
          trusted-users = [ "@wheel" ];
          warn-dirty = false;

          # Opportunistic GC between the weekly runs, so a heavy build day
          # doesn't fill the disk while waiting for Sunday.
          min-free = 5 * 1024 * 1024 * 1024;
          max-free = 15 * 1024 * 1024 * 1024;

          experimental-features = [
            "nix-command"
            "flakes"
          ];

          substituters = [
            "https://cache.bw20.nl"
            "https://cache.nixos.org"
            "https://niri.cachix.org"
            "https://nix-community.cachix.org"
            "https://noctalia.cachix.org"
            "https://numtide.cachix.org"
          ];

          trusted-public-keys = [
            "cache.bw20.nl-1:xkMAP0HGSNkCNnWO1Z1z+c3FrR1uwRzQCvszMZCHf+8="
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ];
        };
      };
    };
  };
}
