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

    # Programs built with their config, instead of a file in $HOME through
    # home-manager (terminal.nix).
    nix-wrapper-modules = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nix-wrapper-modules";
    };

    # Temporary: today's zotero builds on a prebuilt Firefox ESR 140 that
    # nixpkgs marks insecure, and this rev's on an older one from source that
    # isn't marked. permittedInsecurePackages would work too, but Hydra
    # doesn't build insecure packages, so Zotero would build from source
    # here on most nixpkgs updates. Drop when Zotero moves to a newer ESR.
    nixpkgs-zotero.url = "github:nixos/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

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

    # The installer, its rehearsal VM and ISO, and the hosts' yubinstall options
    # (modules/flake/yubinstall.nix). A release, upgraded by hand: it runs as
    # root and wipes disks, and flake.lock keeps the tag's commit, so a moved
    # tag changes nothing. Its disko is only for its own check.
    yubinstall = {
      url = "git+https://codeberg.org/BW20/nixos-yubinstall?ref=refs/tags/0.1.0";

      inputs = {
        disko.follows = "disko";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
