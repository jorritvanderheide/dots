{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    import-tree.url = "github:vic/import-tree";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    preservation.url = "github:nix-community/preservation";

    # A commit, so nupdate doesn't move it: comin runs as root and picks
    # what gets deployed, so a newer one is a choice. Past v0.14.0, for
    # postBuildCommand and buildAttemptsLimit (comin.nix). Its
    # flake-compat only serves its default.nix; an input that follows ""
    # isn't fetched.
    comin = {
      url = "github:nlewo/comin/004a55ced41d72340373ebc6774e29a417512638";

      inputs = {
        flake-compat.follows = "";
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    disko = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/disko";
    };

    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };

    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };

    # pre-commit only serves its checks.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";

      inputs = {
        nixpkgs.follows = "nixpkgs";
        pre-commit.follows = "";
      };
    };

    meetinn = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/ict-netwerk-nijmegen/meetinn";
    };

    new-leaf = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/BW20/new-leaf";
    };

    # niri-flake's and nixos-hardware's own nixpkgs, and niri-flake's niri
    # and xwayland-satellite sources, only build their packages and
    # checks, which we don't use: niri comes from nixpkgs
    # (compositor/default.nix).
    niri-flake = {
      url = "github:sodiboo/niri-flake";

      inputs = {
        niri-stable.follows = "";
        niri-unstable.follows = "";
        nixpkgs-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
        xwayland-satellite-stable.follows = "";
        xwayland-satellite-unstable.follows = "";
      };
    };

    # Programs built with their config, instead of a file in $HOME through
    # home-manager (terminal.nix).
    nix-wrapper-modules = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nix-wrapper-modules";
    };

    nixos-hardware = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nixos/nixos-hardware";
    };

    # Only its module: dapple builds each site itself, from the site's
    # repository and with the nixpkgs that repository's lock pins
    # (blog.nix, blog-jeltje.nix).
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

    weinig-shell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "git+https://codeberg.org/BW20/weinig-shell";
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
