{
  flake.nixosModules.notes =
    {
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              # Brings zotero-headless (see zotero.nix) up with Obsidian and
              # down again once it quits. A second launch, such as an
              # obsidian:// link, hands its arguments to the running Obsidian
              # and returns at once, so every launch holds a shared lock and
              # only the one that can then take it exclusively, the last one
              # out, stops Zotero. --close keeps the lock out of anything
              # Obsidian spawns.
              (symlinkJoin {
                inherit (obsidian) pname version;
                paths = [ obsidian ];

                postBuild = ''
                  rm $out/bin/obsidian
                  ln -s ${writeShellScript "obsidian" ''
                    lock="$XDG_RUNTIME_DIR/obsidian.lock"
                    systemctl --user start --no-block zotero-headless.service
                    ${lib.getExe' util-linux "flock"} --shared --close "$lock" ${lib.getExe obsidian} "$@"
                    status=$?
                    ${lib.getExe' util-linux "flock"} --nonblock --close "$lock" systemctl --user stop zotero-headless.service
                    exit $status
                  ''} $out/bin/obsidian
                '';
              })
              # Scripts/export.sh renders vault notes to docx/pdf/md/tex.
              pandoc
              # texlive is the PDF engine pandoc shells out to. acmart is not
              # used by the export script, which is venue-neutral; it is here
              # for compiling an actual ACM submission locally once there is
              # one, and can go if that never happens.
              (texliveMedium.withPackages (ps: [ ps.acmart ]))
            ];
          }
        ];

        my.research.statePaths = [
          ".config/obsidian"
        ];
      };
    };
}
