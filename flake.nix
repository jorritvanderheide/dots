{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    preservation.url = "github:nix-community/preservation";
    systems.url = "github:nix-systems/default";

    # A commit, so nupdate doesn't move it: comin runs as root and picks
    # what gets deployed, so a newer one is a choice. Past v0.14.0, for
    # postBuildCommand (comin.nix).
    comin = {
      url = "github:nlewo/comin/1399adecc682e557bc3ee914d929f8e20391a148";

      inputs = {
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

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

    # Temporary: zotero fails to build against firefox-esr 153.4
    # (NixOS/nixpkgs#568692), so it comes from the last nixpkgs rev where it
    # still built. Drop once NixOS/nixpkgs#569006 reaches nixos-unstable.
    nixpkgs-zotero.url = "github:nixos/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

    noctalia = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:noctalia-dev/noctalia";
    };

    # Only its module: dapple builds each site itself, from the site's
    # repository and with the nixpkgs that repository's lock pins
    # (blog.nix).
    small-press = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/BW20/small-press";
    };

    # The offsite backup's snapshot, entries and restore command
    # (offsite-backup.nix). A release, upgraded by hand: it runs as root,
    # and flake.lock keeps the tag's commit, so a moved tag changes nothing.
    snapback = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/BW20/snapback?ref=refs/tags/0.1.0";
    };

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
