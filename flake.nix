{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    niri-flake.url = "github:sodiboo/niri-flake";
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    personal-blog.url = "git+ssh://git@codeberg.org/BW20/personal-blog.git";
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

    quickshell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?ref=refs/tags/v0.2.1";
    };

    lanzaboote = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/lanzaboote/v0.4.3";
    };

    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
    };

    starship-jj = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "gitlab:lanastara_foss/starship-jj/0.7.0";
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

    worktrunk = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:max-sixty/worktrunk";
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
