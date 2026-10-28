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
  # cache.nixos.org's builds.
  flake.nixosModules.flake-archive =
    {
      pkgs,
      ...
    }:
    let
      dir = "/var/lib/flake-archive";
      lock = lib.importJSON (inputs.self + "/flake.lock");

      # One folder per node, by its name in flake.lock (nixpkgs_2 is the
      # one nodes.small-press.inputs names), from the store path the flake
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
            # sudo would need a terminal (docs/install.md).
            mode = "0755";
          }
        ];

        # On each switch that changes the inputs, which is when they change,
        # and on the boot, where the marker skips the 15 seconds rsync takes
        # to find nothing to do. --times lets it skip the files it copied
        # before. One rsync per input, through the trailing slash of its
        # link: one over the whole farm would need --copy-dirlinks, which
        # also follows the links inside an input (nixos-hardware has one),
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
              rsync --recursive --links --times --delete --mkpath "$source/" "${dir}/''${source##*/}/"
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
