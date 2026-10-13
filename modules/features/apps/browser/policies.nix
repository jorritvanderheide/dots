# Zen's enterprise policies: what it may do, its extensions and its search
# engines. The program and its profile are in default.nix.
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
      config.home-manager.sharedModules = [
        {
          programs.zen-browser.policies = {
            AutofillAddressEnabled = false;
            AutofillCreditCardEnabled = false;
            BlockAboutAddons = true;
            BlockAboutConfig = true;
            BlockAboutProfiles = true;
            BlockAboutSupport = true;
            CaptivePortal = true;
            DisableAppUpdate = true;
            DisableFirefoxAccounts = true;
            DisableFirefoxScreenshots = true;
            DisableFirefoxStudies = true;
            DisableFormHistory = true;
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

              "jid1-MnnxcxisBPnSXQ@jetpack" = {
                default_area = "menupanel";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
                installation_mode = "force_installed";
                private_browsing = true;
              };

              "uBlock0@raymondhill.net" = {
                default_area = "menupanel";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
                installation_mode = "force_installed";
                private_browsing = true;
              };

              "zotero@chnm.gmu.edu" = {
                default_area = "navbar";
                install_url = "https://www.zotero.org/download/connector/dl?browser=firefox&channel=release";
                installation_mode = "force_installed";
              };

              "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
                default_area = "navbar";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
                installation_mode = "force_installed";
              };

              "{809ea8a3-a45d-41a2-9cb0-e7c7d7321db5}" = {
                default_area = "navbar";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/library_access/latest.xpi";
                installation_mode = "force_installed";
              };

              "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
                default_area = "menupanel";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
                installation_mode = "force_installed";
                private_browsing = true;
              };
            };

            FirefoxHome = {
              Highlights = false;
              Locked = true;
              Pocket = false;
              Search = true;
              Snippets = false;
              SponsoredPocket = false;
              SponsoredTopSites = false;
              TopSites = false;
            };

            FirefoxSuggest = {
              ImproveSuggest = false;
              Locked = true;
              SponsoredSuggestions = false;
              WebSuggestions = false;
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
              Locked = false;
              Sessions = true;
              SiteSettings = false;
            };

            SearchEngines = {
              Default = "Brave";
              PreventInstalls = true;

              Add = [
                {
                  Alias = "@br";
                  IconURL = "https://search.brave.com/favicon.ico";
                  Name = "Brave";
                  SuggestURLTemplate = "https://search.brave.com/api/suggest?q={searchTerms}";
                  URLTemplate = "https://search.brave.com/search?q={searchTerms}";
                }
                {
                  Alias = "@np";
                  IconURL = "https://wiki.nixos.org/favicon.ico";
                  Name = "Nix packages";
                  URLTemplate = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";
                }
                {
                  Alias = "@ng";
                  IconURL = "https://noogle.dev/favicon.ico";
                  Name = "Noogle";
                  URLTemplate = "https://noogle.dev/q?term={searchTerms}";
                }
                {
                  Alias = "@mn";
                  IconURL = "https://mynixos.com/favicon.ico";
                  Name = "My Nixos";
                  URLTemplate = "https://mynixos.com/search?q={searchTerms}";
                }
              ]
              ++ lib.optionals (institution.ezproxyPrefix != null) [
                (
                  {
                    Alias = "@rp";
                    Name = "Radboud proxy";
                    URLTemplate = "${institution.ezproxyPrefix}{searchTerms}";
                  }
                  // lib.optionalAttrs (institution.iconUrl != null) {
                    IconURL = institution.iconUrl;
                  }
                )
              ]
              ++ lib.optionals (institution.librarySearchUrl != null) [
                (
                  {
                    Alias = "@ru";
                    Name = "Radboud University Library";
                    URLTemplate = institution.librarySearchUrl;
                  }
                  // lib.optionalAttrs (institution.iconUrl != null) {
                    IconURL = institution.iconUrl;
                  }
                )
              ]
              ++ [
                {
                  Alias = "@ss";
                  IconURL = "https://www.semanticscholar.org/favicon.ico";
                  Name = "Semantic Scholar";
                  URLTemplate = "https://www.semanticscholar.org/search?q={searchTerms}";
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
              Locked = true;
              MoreFromMozilla = false;
              SkipOnboarding = true;
              UrlbarInterventions = false;
            };
          };
        }
      ];
    };
}
