# Numix-Circle icons, with the folders in the palette's greys. The rest of the
# theme is in default.nix.
{
  flake.nixosModules.theming =
    { pkgs, ... }:
    {
      home-manager.sharedModules = [
        (
          { config, ... }:
          let
            # Numix's folder icons are fixed colors, so a separate theme on top of
            # Numix-Circle carries recolored ones: Numix's custom folder set, whose
            # colors are placeholders, under every name that resolves to the
            # default (orange) set.
            folders = pkgs.runCommand "numix-circle-weinig" { nativeBuildInputs = [ pkgs.findutils ]; } ''
              theme=$out/share/icons/Numix-Circle-Weinig
              mkdir -p $theme
              cd ${pkgs.numix-icon-theme}/share/icons/Numix
              sed -e 's/^Name=.*/Name=Numix Circle Weinig/' -e 's/^Inherits=.*/Inherits=Numix-Circle/' \
                index.theme > $theme/index.theme
              for size in 16 22 24 32 48 64; do
                ln -s $size $theme/$size@2x
              done
              list() {
                find 16 22 24 32 48 64 "$@" \( -path '*/places/*' -o -path '*/actions/*' \)
              }
              list -type f -name 'custom-*' -exec cp --parents --no-preserve=mode -t $theme {} +
              # Resolved in one batch: one realpath per link takes minutes.
              list -type l > $TMPDIR/links
              xargs -a $TMPDIR/links -d '\n' realpath --relative-to=. > $TMPDIR/targets
              paste -d ' ' $TMPDIR/links $TMPDIR/targets | while read -r link target; do
                # target: <size>/<context>/<file>, the context kept for the link
                context=''${target#*/}
                case ''${target##*/} in
                  default-*) ln -s ../''${context/default-/custom-} $theme/$link ;;
                esac
              done
              find $theme -type f -name '*.svg' -exec sed -i -f ${config.programs.weinig.theme.render "numix-folders.sed" ./templates/numix-folders.sed} {} +
            '';
          in
          {
            gtk.iconTheme = {
              name = "Numix-Circle-Weinig";

              package = pkgs.symlinkJoin {
                name = "numix-circle-weinig-with-parents";

                paths = [
                  folders
                  pkgs.numix-icon-theme-circle
                  pkgs.numix-icon-theme
                ];
              };
            };
          }
        )
      ];
    };
}
