{
  inputs,
  ...
}:
{
  flake.nixosModules.browser =
    {
      config,
      lib,
      ...
    }:
    let
      # The home-manager submodules below rebind `config`, so the institution
      # endpoints are resolved out here. Only the endpoints are shared; the
      # display names stay local because this module is not part of the
      # portable research set.
      inherit (config.my.research) institution;
    in
    {
      config = {
        home-manager.sharedModules = [
          inputs.zen-browser.homeModules.beta
          (
            {
              config,
              ...
            }:
            {
              # Tells the stylix target which profile directory to theme
              stylix.targets.zen-browser.profileNames = [ "default" ];

              programs.zen-browser = {
                enable = true;
                setAsDefaultBrowser = true;

                profiles."default" = {
                  containersForce = true;
                  pinsForce = true;
                  spacesForce = true;

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

                  pins =
                    let
                      inherit (config.programs.zen-browser.profiles."default") containers;
                    in
                    {
                      "GitLab" = {
                        container = containers."Work".id;
                        id = "be198a28-a2b5-4362-b43a-d164a31a8215";
                        isEssential = true;
                        position = 1000;
                        url = "https://gitlab.science.ru.nl/dashboard/home";
                      };

                      "PubHubs" = {
                        container = containers."Work".id;
                        id = "efe48942-39d2-41ae-b83f-b214205447ce";
                        isEssential = true;
                        position = 2000;
                        url = "http://localhost:8080";
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
                    "zen.glance.enabled" = false;
                    "zen.tabs.ctrl-tab.ignore-pending-tabs" = true;
                    "zen.tabs.show-newtab-vertical" = false;
                    "zen.window-sync.enabled" = true;
                    "zen.window-sync.sync-only-pinned-tabs" = true;
                  };

                  spaces =
                    let
                      inherit (config.programs.zen-browser.profiles."default") containers;
                    in
                    {
                      "Default" = {
                        container = containers."Default".id;
                        id = "ddb6f565-10ff-4f93-86eb-33f8920aacf4";
                        position = 1000;
                      };

                      "PubHubs" = {
                        container = containers."Work".id;
                        id = "c0d32de6-fd82-4943-ad01-3496469506fb";
                        position = 2000;
                      };
                    };
                };
              };
            }
          )
        ];

        my.preservation.homeDirectories = [
          ".config/zen"
        ];
      };
    };
}
