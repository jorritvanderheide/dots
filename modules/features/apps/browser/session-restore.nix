# Damage control for Zen restoring stray windows: the program and its
# profile are in default.nix. Delete this file once Zen honours
# browser.startup.page again.
{
  flake.nixosModules.browser = {
    config.home-manager.sharedModules = [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          # Zen patched SessionStartup.isAutomaticRestoreEnabled() to a
          # hardcoded `true`, so every window in sessionstore.jsonlz4 is
          # restored whatever browser.startup.page says, and there is no
          # pref to turn that off. Once a stray second window lands in
          # that file it therefore comes back on every later start, and
          # editing the file by hand only holds until the next one
          # appears. Dropping the file before a cold start is the only
          # lever left: Zen then opens exactly one window. Pinned tabs and
          # spaces are unaffected; they live in zen-sessions.jsonlz4,
          # which ZenSessionManager reads separately. Unpinned tabs are
          # already lost on restart anyway, since browser.startup.page is
          # 1 and Zen filters restores down to pinned tabs for anything
          # other than 3.
          #
          # Skipped while Zen is running: a second launch then just hands
          # the URL to the live instance, which owns the file.
          freshStart = pkgs.writeShellApplication {
            name = "zen-beta-fresh-start";
            runtimeInputs = [ pkgs.procps ];

            text = ''
              profile="$HOME/.config/zen/default"

              if ! pgrep -u "$(id -u)" -f 'lib/zen-bin-' > /dev/null; then
                rm -f "$profile"/sessionstore.jsonlz4 \
                  "$profile"/sessionstore-backups/*.jsonlz4 \
                  "$profile"/sessionstore-backups/*.baklz4
              fi

              exec ${lib.getExe config.programs.zen-browser.package} "$@"
            '';
          };
        in
        {
          # Drop windows flagged isZenUnsynced when restoring. Those
          # are the ones zen.window-sync.open-link-in-new-unsynced-
          # window (on by default) spawns for links handed over by
          # another app, so without this a link opened from Zotero or
          # Obsidian can leave a second window in the session that
          # comes back on every later launch.
          #
          # This is damage control, not a fix: Zen patched
          # SessionStartup.isAutomaticRestoreEnabled() to a hardcoded
          # `true`, so browser.startup.page is ignored and every saved
          # window is restored regardless. A duplicate that is *not*
          # flagged unsynced still has to be closed by hand once, and
          # then it stays gone.
          programs.zen-browser.profiles."default".settings."zen.session-store.restore-unsynced-windows" =
            false;

          # Overrides the entry from the package: XDG_DATA_HOME wins over
          # the profile's share/applications, and both the launcher and
          # anything handing over a link resolve the same desktop id.
          # Only the main Exec is rewritten; the New Window and Private
          # Window actions are for an already-running Zen.
          xdg.dataFile."applications/zen-beta.desktop".source =
            pkgs.runCommand "zen-beta-fresh-start.desktop" { }
              ''
                substitute ${config.programs.zen-browser.package}/share/applications/zen-beta.desktop $out \
                  --replace-fail 'Exec=zen-beta --name zen-beta %U' 'Exec=${lib.getExe freshStart} --name zen-beta %U'
              '';
        }
      )
    ];
  };
}
