{
  inputs,
  lib,
  ...
}:
{
  # A copy of every input in flake.lock, the inputs' own included, on
  # /persist and so in the offsite backup: this flake can still be built if
  # a forge or a repository is gone. Plain trees rather than archives, so
  # an update copies, and restic uploads, only the files it changed. It
  # keeps the inputs, not the sources their packages download, nor
  # cache.nixos.org's builds. dapple's build needs every node in the lock,
  # even one the hosts don't use, like treefmt-nix.
  #
  # If an input's forge or repository is gone, or a tag was moved, build
  # from its copy, on rocinante. <node> is its name in flake.lock (an
  # input's own input has a node of its own, like lanzaboote's crane), and
  # <input> its path, like nixpkgs or lanzaboote/crane:
  #
  #   mkdir -p ~/flake-archive
  #   ssh nixos@dapple tar -C /var/lib/flake-archive -c <node> | tar -x -C ~/flake-archive
  #   nix eval --impure --expr '(builtins.fromJSON (builtins.readFile /etc/nixos/flake.lock)).nodes.<node>.locked'
  #   nix flake lock /etc/nixos --override-input <input> \
  #     "path:$HOME/flake-archive/<node>?rev=<rev>&lastModified=<lastModified>"
  #
  # with the rev and lastModified the eval prints, and &revCount=<revCount>
  # if it has one. The copy has no git history, so without them nixpkgs'
  # version label reads 19700101.dirty and every store path changes. Commit
  # flake.lock (nswitch refuses uncommitted changes). Until the input has a
  # new home (a repository of your own on Codeberg, as its url in
  # flake.nix), nupdate fails on it: update the others by name.
  #
  # With dapple gone too, restore the node from the backup instead of the
  # tar, the way offsite-prune reaches it (RESTIC_REPOSITORY and dapple's
  # restic_password and storj keys): `restic restore latest --include
  # /var/lib/flake-archive/<node> --target <dir>`.
  flake.nixosModules.flake-archive =
    {
      pkgs,
      ...
    }:
    let
      dir = "/var/lib/flake-archive";
      lock = lib.importJSON (inputs.self + "/flake.lock");

      # One folder per node, by its name in flake.lock (a name two nodes
      # share gets a suffix, like nixpkgs_2), from the store path the flake
      # itself was evaluated with.
      sources = pkgs.linkFarm "flake-inputs" (
        lib.mapAttrs (_: node: builtins.fetchTree node.locked) (removeAttrs lock.nodes [ lock.root ])
      );
    in
    {
      config = {
        my.offsite-backup.entries.flake-archive.paths = [ dir ];

        my.preservation.systemDirectories = [
          {
            directory = dir;

            # Public sources, which the nixos user copies over SSH, where
            # sudo would need a terminal (the tar in the header).
            mode = "0755";
          }
        ];

        # On each switch that changes the inputs, which is when they change,
        # and on the boot, where the marker skips the 15 seconds rsync takes
        # to find nothing to do. --checksum because every file in the store
        # has mtime 1, so an edit that keeps a file's size looks unchanged
        # to rsync, and --executability because the narHash covers that bit.
        # One rsync per input, through the trailing slash of its
        # link: one over the whole farm would need --copy-dirlinks, which
        # also follows the links inside an input,
        # and the copy would no longer match its narHash.
        systemd.services.flake-archive = {
          description = "Copy the flake inputs' sources to /persist";
          path = [ pkgs.rsync ];
          unitConfig.RequiresMountsFor = [ dir ];
          wantedBy = [ "multi-user.target" ];

          script = ''
            if [[ -e ${dir}/.source && $(<${dir}/.source) == ${sources} ]]; then
              exit 0
            fi
            shopt -s nullglob
            for source in ${sources}/*; do
              rsync --recursive --links --times --delete --mkpath --checksum --executability "$source/" "${dir}/''${source##*/}/"
            done
            # Nodes the lock no longer has.
            for copy in ${dir}/*; do
              if [[ ! -e ${sources}/''${copy##*/} ]]; then
                rm -rf "$copy"
              fi
            done
            echo ${sources} > ${dir}/.source
          '';

          serviceConfig = {
            RemainAfterExit = true;
            Type = "oneshot";
          };
        };
      };
    };
}
