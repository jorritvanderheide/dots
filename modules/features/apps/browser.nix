{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.browser =
    {
      config,
      ...
    }:
    let
      cfg = config.features.browser;
    in
    {
      options.features.browser = {
        enable = lib.mkEnableOption "web browser";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          inputs.zen-browser.homeModules.beta
          (
            {
              config,
              ...
            }:
            {
              programs.zen-browser = {
                enable = true;

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
                  DisableSecurityBypass = true;
                  DisableSetDesktopBackground = true;
                  DisableSystemAddonUpdate = true;
                  DisableTelemetry = true;
                  DisplayBookmarksToolbar = "never";
                  DisplayMenuBar = "default-off";
                  DontCheckDefaultBrowser = true;
                  # HttpsOnlyMode = "force_enabled";
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

                  Cookies = {
                    Behavior = "reject-foreign";
                    Locked = true;
                  };

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
                    "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
                      default_area = "menupanel";
                      installation_mode = "force_installed";
                      install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
                    };
                    "{a07d2d7e-9071-42b3-8179-dceaab34345b}" = {
                      installation_mode = "force_installed";
                      install_url = "https://addons.mozilla.org/firefox/downloads/latest/rose-pine-moon-normal/latest.xpi";
                    };
                    "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
                      default_area = "menupanel";
                      installation_mode = "force_installed";
                      install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
                    };
                    "jid1-MnnxcxisBPnSXQ@jetpack" = {
                      default_area = "menupanel";
                      installation_mode = "force_installed";
                      install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
                    };
                    "uBlock0@raymondhill.net" = {
                      default_area = "menupanel";
                      installation_mode = "force_installed";
                      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
                    };
                  };

                  FirefoxHome = {
                    Search = true;
                    TopSites = false;
                    SponsoredTopSites = false;
                    Highlights = false;
                    Pocket = false;
                    SponsoredPocket = false;
                    Snippets = false;
                    Locked = true;
                  };

                  FirefoxSuggest = {
                    WebSuggestions = false;
                    SponsoredSuggestions = false;
                    ImproveSuggest = false;
                    Locked = true;
                  };

                  GenerativeAI = {
                    Enabled = false;
                    Locked = true;
                  };

                  Homepage = {
                    Locked = false;
                    StartPage = "homepage";
                  };

                  HttpAllowlist = [
                    "http://localhost"
                    # TODO Add secret ip with sops
                  ];

                  SanitizeOnShutdown = {
                    Cache = true;
                    Cookies = false;
                    FormData = true;
                    History = false;
                    Sessions = false;
                    SiteSettings = false;
                    Locked = false;
                  };

                  SearchEngines = {
                    Default = "Kagi";
                    PreventInstalls = true;

                    Add = [
                      {
                        Name = "Kagi";
                        URLTemplate = "https://kagi.com/search?q={searchTerms}";
                        IconURL = "https://kagi.com/favicon.ico";
                        Alias = "@kg";
                        Description = "Better search results with no ads.";
                        SuggestURLTemplate = "https://kagi.com/api/autosuggest?q={searchTerms}";
                      }
                      {
                        Name = "Perplexity AI";
                        URLTemplate = "https://perplexity.ai/search?q={searchTerms}&copilot=false";
                        IconURL = "https://perplexity.ai/favicon.ico";
                        Alias = "@ai";
                        Description = "Perplexity is your AI-powered Swiss Army knife for information discovery and curiosity.";
                      }
                      {
                        Name = "Nix packages";
                        URLTemplate = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";
                        IconURL = "https://wiki.nixos.org/favicon.ico";
                        Alias = "@np";
                      }
                      {
                        Name = "Nix functions";
                        URLTemplate = "https://noogle.dev/q?term={searchTerms}";
                        IconURL = "https://noogle.dev/favicon.ico";
                        Alias = "@ng";
                      }
                      {
                        Name = "NixOS Wiki";
                        URLTemplate = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
                        IconURL = "https://wiki.nixos.org/favicon.ico";
                        Alias = "@nw";
                      }
                      {
                        Name = "My Nixos";
                        URLTemplate = "https://mynixos.com/search?q={searchTerms}";
                        IconURL = "https://mynixos.com/favicon.ico";
                        Alias = "@mn";
                      }
                    ];

                    Remove = [
                      "Bing"
                      "eBay"
                      "Ecosia"
                      "Google"
                      "Perplexity"
                      "Qwant"
                      "Wikipedia (en)"
                    ];
                  };

                  UserMessaging = {
                    ExtensionRecommendations = false;
                    FeatureRecommendations = false;
                    UrlbarInterventions = false;
                    SkipOnboarding = true;
                    MoreFromMozilla = false;
                    FirefoxLabs = false;
                    Locked = true;
                  };
                };

                profiles."default" = {
                  containersForce = true;
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

                  pinsForce = true;
                  pins =
                    let
                      workspaces = config.programs.zen-browser.profiles."default".spaces;
                    in
                    {
                      # Work
                      "GitLab" = {
                        id = "be198a28-a2b5-4362-b43a-d164a31a8215";
                        url = "https://gitlab.science.ru.nl/dashboard/home";
                        workspace = workspaces."PubHubs".id;
                        position = 1000;
                      };
                    };

                  spacesForce = true;
                  spaces =
                    let
                      containers = config.programs.zen-browser.profiles."default".containers;
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

                  settings = {
                    ## General
                    "browser.sessionstore.resume_from_crash" = false;

                    ## Cachining
                    "browser.cache.disk.enable" = false;
                    "browser.cache.memory.enable" = true;
                    "browser.cache.memory.capacity" = 32768;

                    ## AI
                    "browser.ml.enable" = false;

                    ## Tabs
                    "browser.tabs.unloadOnLowMemory" = true;
                    "browser.low_commit_space_threshold_percent" = 100;
                    "browser.tabs.min_inactive_duration_before_unload" = 3600000;

                    ## Styling
                    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                  };
                };
              };

              home.sessionVariables.BROWSER = "zen";

              # Fix for missing profile warning
              stylix.targets.zen-browser.profileNames = [ "default" ];
            }
          )
        ];
      };
    };
}
