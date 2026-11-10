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
                  ln -s ${
                    lib.getExe (writeShellApplication {
                      name = "obsidian";

                      text = ''
                        lock="$XDG_RUNTIME_DIR/obsidian.lock"
                        systemctl --user start --no-block zotero-headless.service || true
                        status=0
                        ${lib.getExe' util-linux "flock"} --shared --close "$lock" ${lib.getExe obsidian} "$@" || status=$?
                        ${lib.getExe' util-linux "flock"} --nonblock --close "$lock" systemctl --user stop zotero-headless.service || true
                        exit $status
                      '';
                    })
                  } $out/bin/obsidian
                '';
              })
              # Due Credit exports vault notes through it.
              pandoc
              # The PDF engines pandoc shells out to: xelatex for Due Credit, and
              # lualatex for app/export/verslag.sh in the vault, which is what
              # these two are for.
              (texliveSmall.withPackages (ps: [
                ps.lualatex-math
                ps.selnolig
              ]))
            ];
          }
        ];

        my.research.statePaths = [
          ".config/obsidian"
        ];
      };
    };
}
