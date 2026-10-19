{
  inputs,
  ...
}:
{
  # Zen's part of the theme: noctalia renders its colors, and Zen's
  # autoconfig swaps them in while it runs.
  flake.nixosModules.theming =
    {
      pkgs,
      ...
    }:
    {
      home-manager.sharedModules = [
        (
          { config, ... }:
          let
            zenCache = "${config.xdg.cacheHome}/noctalia/zen-browser";
          in
          {
            programs.noctalia.settings.theme.templates.user = {
              zen_browser_chrome = {
                input_path = "${./noctalia-templates/zen-userChrome.css}";
                output_path = "${zenCache}/zen-userChrome.css";
              };

              zen_browser_content = {
                input_path = "${./noctalia-templates/zen-userContent.css}";
                output_path = "${zenCache}/zen-userContent.css";
              };

              zen_colors = {
                input_path = "${./noctalia-templates/zen-colors.css}";
                output_path = "${zenCache}/zen-colors.css";
              };
            };

            programs.zen-browser.profiles."default" = {
              # 2 = follow the system color-scheme.
              # The imported CSS carries both variants under
              # prefers-color-scheme.
              settings."zen.view.window.scheme" = 2;

              # Both files' colors come from zen-colors.css, loaded by the
              # autoconfig (noctalia.cfg); userContent is the same import.
              userChrome = ''@import url("file://${zenCache}/zen-userChrome.css");'';
              userContent = ''@import url("file://${zenCache}/zen-userContent.css");'';
            };

            # Firefox only reads userChrome/userContent at startup, so colors
            # imported there would stay stale after a wallpaper or light/dark
            # change. Zen's autoconfig (noctalia.cfg, privileged JS run at
            # startup) instead registers zen-colors.css as a user stylesheet,
            # checks its timestamp every second, and swaps in the new version
            # once noctalia has finished rewriting it; the stylesheet service
            # applies that to open windows immediately.
            #
            # Installed into the unwrapped package, not via the module's
            # extraPrefs: wrapFirefox writes mozilla.cfg next to its own copy
            # of the binary, but Zen's binary keeps its unwrapped name, so the
            # wrapper only symlinks it and Gecko reads mozilla.cfg next to the
            # resolved /proc/self/exe, i.e. the unwrapped package. (The zen
            # module bakes its policies into the unwrapped package for the same
            # reason, so the beta-unwrapped.override here passes them on.)
            # Named noctalia.cfg/noctalia-autoconfig.js because the wrapper
            # writes its own (unused) mozilla.cfg/autoconfig.js next to the
            # symlinks it makes to these files.
            programs.zen-browser.unwrappedPackage =
              let
                zen = config.programs.zen-browser;
                autoconfigPrefs = pkgs.writeText "noctalia-autoconfig.js" ''
                  pref("general.config.filename", "noctalia.cfg");
                  pref("general.config.obscure_value", 0);
                  // Off, like the zen flake's Sine loader does: in the sandbox the script
                  // has no Cc/Ci and cannot reach the stylesheet service.
                  pref("general.config.sandbox_enabled", false);
                '';
                autoconfig = pkgs.writeText "noctalia.cfg" ''
                  // First line must be a comment.
                  // noctalia live colors (theming/zen.nix)
                  // Never throws: an uncaught error here makes Firefox show an error
                  // dialog at startup.
                  const log = (e) => { try { console.error("noctalia live colors:", e); } catch (_) {} };
                  try {
                    const path = "${zenCache}/zen-colors.css";
                    const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
                    const ios = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
                    let sheet = null;
                    let applied = 0;
                    let seen = 0;
                    const mtime = () => {
                      const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
                      file.initWithPath(path);
                      return file.exists() ? file.lastModifiedTime : 0;
                    };
                    const apply = (stamp) => {
                      // The query makes each version a new URI, so the sheet
                      // cache can't hand back the old one.
                      const next = ios.newURI("file://" + path + "?" + stamp);
                      sss.loadAndRegisterSheet(next, sss.USER_SHEET);
                      if (sheet) sss.unregisterSheet(sheet, sss.USER_SHEET);
                      sheet = next;
                      applied = stamp;
                    };
                    const poll = () => {
                      try {
                        const stamp = mtime();
                        // Apply only once the timestamp held for a whole tick,
                        // so a file still being written isn't loaded half-done.
                        if (stamp !== seen) { seen = stamp; return; }
                        if (stamp && stamp !== applied) apply(stamp);
                      } catch (e) {
                        log(e);
                      }
                    };
                    seen = mtime();
                    if (seen) apply(seen);
                    const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
                    timer.initWithCallback({ notify: poll }, 1000, Ci.nsITimer.TYPE_REPEATING_SLACK);
                    // The observer service holds this observer strongly, which
                    // keeps the timer referenced (and so running) until quit.
                    Cc["@mozilla.org/observer-service;1"].getService(Ci.nsIObserverService)
                      .addObserver({ observe: () => timer.cancel() }, "quit-application");
                  } catch (e) {
                    log(e);
                  }
                '';
              in
              (inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.override {
                inherit (zen) policies enablePrivateDesktopEntry;
              }).overrideAttrs
                (old: {
                  postInstall = (old.postInstall or "") + ''
                    for libdir in "$out"/lib/zen-bin-*; do
                      chmod -R u+w "$libdir/defaults"
                      install -m 644 ${autoconfig} "$libdir/noctalia.cfg"
                      install -D -m 644 ${autoconfigPrefs} "$libdir/defaults/pref/noctalia-autoconfig.js"
                    done
                  '';
                });
          }
        )
      ];
    };
}
