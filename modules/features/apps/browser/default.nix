{
  flake.nixosModules.browser =
    {
      config,
      lib,
      ...
    }:
    let
      # The home-manager.sharedModules entries rebind `config`, so the
      # institution endpoints are resolved out here. Only the endpoints are
      # shared; the display names stay local because this module is not part
      # of the portable research set.
      inherit (config.my.research) institution;
    in
    {
      config = {
        home-manager.sharedModules = [
          {
            programs.firefox = {
              enable = true;

              profiles."default" = {
                containersForce = true;

                bookmarks = {
                  force = true;

                  # No `toolbar = true` anywhere, so this lands in the
                  # bookmarks menu (hamburger > Bookmarks, or Ctrl+Shift+O)
                  # rather than the toolbar, which DisplayBookmarksToolbar
                  # keeps hidden. It has to be *clicked*: giving it a
                  # `keyword` would not help, since the urlbar has silently
                  # dropped keyword-invoked bookmarklets since Firefox 68
                  # (mozilla bug 1552141).
                  settings = lib.optionals (institution.ezproxyPrefix != null) [
                    {
                      name = "Library";

                      bookmarks = [
                        {
                          name = "Radboud proxy";
                          url = "javascript:void(location.href='${institution.ezproxyPrefix}'+encodeURIComponent(location.href))";
                        }
                      ];
                    }
                  ];
                };

                containers = {
                  "Default" = {
                    color = "toolbar";
                    id = 1;
                  };

                  "Work" = {
                    color = "blue";
                    id = 2;
                  };
                };

                # Keys have to be flat, quoted pref names. The module runs
                # each top-level attribute's value through toJSON, so a
                # nested attrset lands in user.js as one junk pref, e.g.
                # user_pref("browser", "{\"cache\":{...}}"), and every
                # setting inside it silently never applies.
                settings = {
                  "browser.cache.disk.enable" = false;
                  "browser.cache.memory.capacity" = 32768;
                  "browser.cache.memory.enable" = true;
                  "browser.low_commit_space_threshold_percent" = 100;
                  "browser.ml.enable" = false;
                  "browser.sessionstore.resume_from_crash" = false;
                  "browser.startup.homepage_override.mstone" = "ignore";
                  "browser.tabs.min_inactive_duration_before_unload" = 3600000;
                  "browser.tabs.unloadOnLowMemory" = true;
                  "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                };
              };
            };

            xdg.mimeApps.defaultApplications =
              lib.genAttrs [
                "application/xhtml+xml"
                "text/html"
                "x-scheme-handler/about"
                "x-scheme-handler/http"
                "x-scheme-handler/https"
                "x-scheme-handler/unknown"
              ] (_: "firefox.desktop")
              // {
                "application/json" = "dev.zed.Zed.desktop";
                "text/markdown" = "dev.zed.Zed.desktop";
                "text/plain" = "dev.zed.Zed.desktop";
                "x-scheme-handler/mailto" = "thunderbird.desktop";
              };
          }
        ];

        my.preservation.homeDirectories = [
          ".config/mozilla"
        ];
      };
    };
}
