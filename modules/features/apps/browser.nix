{
  inputs,
  ...
}:
{
  flake.nixosModules.browser = {
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

              policies = {
                AutofillAddressEnabled = false;
                AutofillCreditCardEnabled = false;
                BlockAboutConfig = true;
                BlockAboutAddons = true;
                BlockAboutProfiles = true;
                BlockAboutSupport = true;
                CaptivePortal = true;
                DisableAppUpdate = true;
                DisableFirefoxAccounts = true;
                DisableFormHistory = true;
                DisableFirefoxScreenshots = true;
                DisableFirefoxStudies = true;
                DisablePocket = true;
                DisableProfileImport = true;
                DisableSetDesktopBackground = true;
                DisableSystemAddonUpdate = true;
                DisableTelemetry = true;
                DisplayBookmarksToolbar = "never";
                DisplayMenuBar = "default-off";
                DontCheckDefaultBrowser = true;
                HttpsOnlyMode = "force_enabled";
                NewTabPage = true;
                NoDefaultBookmarks = true;
                OverrideFirstRunPage = "";
                OverridePostUpdatePage = "";
                PasswordManagerEnabled = false;
                PictureInPicture = false;
                SearchSuggestEnabled = true;
                ShowHomeButton = true;
                SkipTermsOfUse = true;
                TranslateEnabled = false;

                DNSOverHTTPS = {
                  Enabled = false;
                  Locked = false;
                };

                EnableTrackingProtection = {
                  Category = "strict";
                  Locked = true;
                  Value = true;
                };

                ExtensionSettings = {
                  "*".installation_mode = "blocked";

                  "*".allowed_types = [
                    "extension"
                    "theme"
                  ];

                  "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
                    default_area = "navbar";
                    installation_mode = "force_installed";
                    install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
                  };

                  "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
                    default_area = "menupanel";
                    installation_mode = "force_installed";
                    install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
                    private_browsing = true;
                  };

                  "jid1-MnnxcxisBPnSXQ@jetpack" = {
                    default_area = "menupanel";
                    installation_mode = "force_installed";
                    install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
                    private_browsing = true;
                  };

                  "uBlock0@raymondhill.net" = {
                    default_area = "menupanel";
                    installation_mode = "force_installed";
                    install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
                    private_browsing = true;
                  };
                };

                FirefoxHome = {
                  Highlights = false;
                  Pocket = false;
                  Search = true;
                  Snippets = false;
                  SponsoredPocket = false;
                  SponsoredTopSites = false;
                  TopSites = false;
                  Locked = true;
                };

                FirefoxSuggest = {
                  ImproveSuggest = false;
                  SponsoredSuggestions = false;
                  WebSuggestions = false;
                  Locked = true;
                };

                GenerativeAI = {
                  Enabled = false;
                  Locked = true;
                };

                Homepage = {
                  StartPage = "homepage";
                  Locked = false;
                };

                HttpAllowlist = [
                  "http://localhost"
                  "http://localhost:8001"
                  "http://localhost:8080"
                  "http://145.137.190.196"
                  "http://100.64.0.2"
                ];

                SanitizeOnShutdown = {
                  Cache = true;
                  Cookies = false;
                  FormData = true;
                  History = false;
                  Sessions = true;
                  SiteSettings = false;
                  Locked = false;
                };

                SearchEngines = {
                  Default = "Brave";
                  PreventInstalls = true;

                  Add = [
                    {
                      Alias = "@br";
                      Name = "Brave";
                      IconURL = "https://search.brave.com/favicon.ico";
                      SuggestURLTemplate = "https://search.brave.com/api/suggest?q={searchTerms}";
                      URLTemplate = "https://search.brave.com/search?q={searchTerms}";
                    }
                    {
                      Alias = "@np";
                      Name = "Nix packages";
                      IconURL = "https://wiki.nixos.org/favicon.ico";
                      URLTemplate = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";
                    }
                    {
                      Alias = "@ng";
                      Name = "Noogle";
                      IconURL = "https://noogle.dev/favicon.ico";
                      URLTemplate = "https://noogle.dev/q?term={searchTerms}";
                    }
                    {
                      Alias = "@nw";
                      Name = "NixOS Wiki";
                      IconURL = "https://wiki.nixos.org/favicon.ico";
                      URLTemplate = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
                    }
                    {
                      Alias = "@mn";
                      Name = "My Nixos";
                      IconURL = "https://mynixos.com/favicon.ico";
                      URLTemplate = "https://mynixos.com/search?q={searchTerms}";
                    }
                  ];

                  Remove = [
                    "bing"
                    "duckduckgo"
                    "ebay-nl"
                    "ecosia"
                    "google"
                    "perplexity"
                    "qwant"
                    "wikipedia"
                  ];
                };

                UserMessaging = {
                  ExtensionRecommendations = false;
                  FeatureRecommendations = false;
                  FirefoxLabs = false;
                  MoreFromMozilla = false;
                  SkipOnboarding = true;
                  UrlbarInterventions = false;
                  Locked = true;
                };
              };

              profiles."default" = {
                containersForce = true;
                pinsForce = true;
                spacesForce = true;

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

                settings = {
                  toolkit.legacyUserProfileCustomizations.stylesheets = true;

                  browser = {
                    low_commit_space_threshold_percent = 100;
                    startup.homepage_override.mstone = "ignore";
                    sessionstore.resume_from_crash = false;
                    ml.enable = false;

                    cache = {
                      disk.enable = false;

                      memory = {
                        enable = true;
                        capacity = 32768;
                      };
                    };

                    tabs = {
                      tabs.min_inactive_duration_before_unload = 3600000;
                      unloadOnLowMemory = true;
                    };
                  };

                  zen = {
                    glance.enabled = false;

                    tabs = {
                      ctrl-tab.ignore-pending-tabs = true;
                      show-newtab-vertical = false;
                    };

                    window-sync = {
                      enabled = true;
                      sync-only-pinned-tabs = true;
                    };
                  };
                };

                spaces =
                  let
                    inherit (config.programs.zen-browser.profiles."default") containers;
                  in
                  {
                    "Default" = {
                      id = "ddb6f565-10ff-4f93-86eb-33f8920aacf4";
                      container = containers."Default".id;
                      position = 1000;
                    };

                    "PubHubs" = {
                      id = "c0d32de6-fd82-4943-ad01-3496469506fb";
                      container = containers."Work".id;
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
