{
  inputs,
  ...
}:
{
  flake.nixosModules.nix = {
    config = {
      nixpkgs.config.allowUnfree = true;

      nix = {
        # Yields to interactive work under contention, full speed when idle.
        # Preferable to capping max-jobs/cores, which slows builds always.
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

          # Opportunistic GC between the weekly runs, so a heavy build day
          # doesn't fill the disk while waiting for Sunday.
          max-free = 15 * 1024 * 1024 * 1024;
          min-free = 5 * 1024 * 1024 * 1024;

          nix-path = [ "nixpkgs=${inputs.nixpkgs}" ];

          # Only the official cache here. A trusted key may sign any path,
          # not just its own project's, so each extra cache is added by the
          # module (or host) that actually needs it.
          substituters = [ "https://cache.nixos.org" ];

          trusted-users = [ "@wheel" ];
          warn-dirty = false;

          experimental-features = [
            "nix-command"
            "flakes"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          ];
        };
      };
    };
  };
}
