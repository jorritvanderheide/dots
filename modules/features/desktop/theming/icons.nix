# Numix-Circle icons, with the folders in the wallpaper's colors. The rest
# of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { pkgs, ... }:
    {
      home-manager.sharedModules = [
        (
          { config, lib, ... }:
          let
            # Numix's folder icons are fixed colors, so a separate theme on
            # top of Numix-Circle carries recolored ones. This is its
            # skeleton: Numix's custom folder set, whose colors are
            # placeholders, under every name that resolves to the default
            # (orange) set.
            numixFolders = pkgs.runCommand "numix-folders" { } ''
              cd ${pkgs.numix-icon-theme}/share/icons/Numix
              mkdir $out
              sed -e 's/^Name=.*/Name=Numix Circle Noctalia/' -e 's/^Inherits=.*/Inherits=Numix-Circle/' \
                index.theme > $out/index.theme
              for size in 16 22 24 32 48 64; do
                ln -s $size $out/$size@2x
              done
              folders() {
                find 16 22 24 32 48 64 "$@" \( -path '*/places/*' -o -path '*/actions/*' \)
              }
              folders -type f -name 'custom-*' -exec cp --parents --no-preserve=mode -t $out {} +
              # Resolved in one batch: one realpath per link takes minutes.
              folders -type l > $TMPDIR/links
              xargs -a $TMPDIR/links -d '\n' realpath --relative-to=. > $TMPDIR/targets
              paste -d ' ' $TMPDIR/links $TMPDIR/targets | while read -r link target; do
                # target: <size>/<context>/<file>, the context kept for the link
                context=''${target#*/}
                case ''${target##*/} in
                  default-*) ln -s ../''${context/default-/custom-} $out/$link ;;
                esac
              done
            '';

            # Recolors a fresh copy of the skeleton and points the theme at
            # it. Running GTK apps (Nautilus) only reload their icons when
            # the theme's name changes, so the theme goes by two names,
            # both pointing at the new copy, and each run switches dconf to
            # the other one. Nothing ever shows the old colors in between.
            numixFoldersApply = pkgs.writeShellApplication {
              name = "numix-folders-apply";

              runtimeInputs = with pkgs; [
                coreutils
                dconf
                findutils
                gnused
              ];

              text = ''
                icons=${config.xdg.dataHome}/icons
                copies=${config.xdg.cacheHome}/noctalia/numix-folders
                mkdir -p "$icons" "$copies"
                new=$(mktemp -d "$copies/XXXXXX")
                cp -rT --no-preserve=mode ${numixFolders} "$new"
                find "$new" -type f -name '*.svg' -exec sed -i -f "$1" {} +
                chmod 755 "$new"
                for name in Numix-Circle-Noctalia Numix-Circle-Noctalia-Reload; do
                  ln -sfn "$new" "$icons/$name.new"
                  mv -T "$icons/$name.new" "$icons/$name"
                done
                find "$copies" -mindepth 1 -maxdepth 1 ! -path "$new" -exec rm -rf {} +

                key=/org/gnome/desktop/interface/icon-theme
                if [[ $(dconf read $key) == "'Numix-Circle-Noctalia'" ]]; then
                  dconf write $key "'Numix-Circle-Noctalia-Reload'"
                else
                  dconf write $key "'Numix-Circle-Noctalia'"
                fi
              '';
            };
          in
          {
            gtk.iconTheme = {
              package = pkgs.numix-icon-theme-circle;

              # Numix-Circle with the folders in the wallpaper's colors
              # (numixFolders), the name GTK's settings and Qt keep;
              # dconf flips between it and its -Reload twin (see
              # numixFoldersApply). The same in light mode: noctalia
              # doesn't switch icon themes.
              name = "Numix-Circle-Noctalia";
            };

            programs.noctalia.settings.theme.templates.user = {
              numix_folders = {
                input_path = "${./noctalia-templates/numix-folders.sed}";
                output_path = "${config.xdg.cacheHome}/noctalia/numix-folders.sed";
                post_hook = "${lib.getExe numixFoldersApply} ${config.xdg.cacheHome}/noctalia/numix-folders.sed";
              };
            };
          }
        )
      ];
    };
}
