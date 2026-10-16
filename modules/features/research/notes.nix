{
  flake.nixosModules.notes =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              obsidian
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
