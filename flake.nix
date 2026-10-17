{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # Temporary: zotero fails to build against firefox-esr 153.4
    # (NixOS/nixpkgs#568692), so it comes from the last nixpkgs rev where it
    # still built. Drop once NixOS/nixpkgs#569006 reaches nixos-unstable.
    nixpkgs-zotero.url = "github:nixos/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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

    lanzaboote = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/lanzaboote/v1.2.0";
    };

    meetinn = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/ict-netwerk-nijmegen/meetinn";
    };

    new-leaf = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/BW20/new-leaf";
    };

    # niri-flake's and nixos-hardware's own nixpkgs only build their
    # packages and checks, which we don't use: niri comes from nixpkgs
    # (compositor.nix).
    niri-flake = {
      url = "github:sodiboo/niri-flake";

      inputs = {
        nixpkgs-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
    };

    nixos-hardware = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nixos/nixos-hardware";
    };

    noctalia = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:noctalia-dev/noctalia";
    };

    # Not following nixpkgs: the blog builds with the Hugo it pins, as a newer
    # one may not build it. Only its static files reach dapple.
    personal-blog.url = "git+https://codeberg.org/BW20/personal-blog";

    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
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
