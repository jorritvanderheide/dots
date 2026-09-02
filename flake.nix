{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Pinned to the last commit where bitwarden-desktop was 2026.6.1 --
    # dapple's Vaultwarden is stuck on 1.36.0 for now, which only speaks to
    # Bitwarden clients up through 2026.6.1 (2026.7.0+ needs Vaultwarden
    # 1.37.2+: https://github.com/dani-garcia/vaultwarden/discussions/7473).
    # Remove this pin once dapple's Vaultwarden is updated.
    nixpkgs-bitwarden-pin.url = "github:nixos/nixpkgs/cc451f6f164363f960b53cb76be15a6ddd975146";
    preservation.url = "github:nix-community/preservation";
    systems.url = "github:nix-systems/default";

    disko = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/disko";
    };

    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };

    niri-flake.url = "github:sodiboo/niri-flake";

    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
    };

    stylix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:danth/stylix";
    };

    system76-scheduler-niri = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Kirottu/system76-scheduler-niri";
    };

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";

      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
