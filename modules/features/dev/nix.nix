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

          experimental-features = [
            "nix-command"
            "flakes"
          ];

          substituters = [
            "https://cache.garnix.io"
            "https://cache.nixos.org"
            "https://niri.cachix.org"
            "https://nix-community.cachix.org"
            "https://numtide.cachix.org"
          ];

          trusted-public-keys = [
            "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ];
        };
      };
    };
  };
}
