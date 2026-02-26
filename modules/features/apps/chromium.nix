{
  flake.nixosModules.chromium =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.settings.chromium;
    in
    {
      options.settings.chromium = {
        enable = lib.mkEnableOption "Chromium browser";
      };

      config = lib.mkIf cfg.enable {

        programs.chromium = {
          enable = true;

          extraOpts = {
            ExtensionInstallForcelist = [
              "ddkjiahejlhfcafbddmgiahcphecmpfh"
              "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude
              "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
              "pkehgijcmpdhfbdbbnkijodmdjhbjlgp" # Privacy Badger
            ];

            # Autofill
            "AutofillAddressEnabled" = false;
            "AutofillCreditCardEnabled" = false;

            # Updates
            "AutoUpdateCheckPeriodMinutes" = 0;

            # Sync and Google services
            "BrowserSignin" = 0;
            "SyncDisabled" = true;
            "CloudPrintSubmitEnabled" = false;

            # Privacy
            "SearchSuggestEnabled" = true;
            "AlternateErrorPagesEnabled" = false;
            "BuiltInDnsClientEnabled" = false;
            "MetricsReportingEnabled" = false;
            "PasswordManagerEnabled" = false;
            "SpellcheckEnabled" = false;
            "TranslateEnabled" = false;

            # Background services
            "BackgroundModeEnabled" = false;
            "BookmarkBarEnabled" = false;
            "PromotionalTabsEnabled" = false;
            "PromptForDownloadLocation" = true;

            # Cookies and tracking
            "BlockThirdPartyCookies" = true;
            "DefaultCookiesSetting" = 1;

            # Security
            "AdvancedProtectionAllowed" = true;
            "DnsOverHttpsMode" = "off";
            "HttpsOnlyMode" = "force_enabled";
            "SafeBrowsingEnabled" = true;
            "SafeBrowsingProtectionLevel" = 2;
            "SSLErrorOverrideAllowed" = false;

            # Media capture
            "AudioCaptureAllowed" = true;
            "DeveloperToolsAvailable" = true;
            "ScreenCaptureAllowed" = true;
            "VideoCaptureAllowed" = true;

            # Homepage and startup
            "HomepageIsNewTabPage" = true;
            "HomepageLocation" = "";
            "NewTabPageLocation" = "chrome://new-tab-page";
            "RestoreOnStartup" = 0;
            "ShowHomeButton" = true;

            # Clear data on shutdown
            "ClearBrowsingDataOnExitList" = [
              "browsing_history"
              "download_history"
              "cached_images_and_files"
            ];

            # Promotional content
            "WelcomePageOnOSUpgradeEnabled" = false;

            # Privacy sandbox
            "PrivacySandboxAdMeasurementEnabled" = false;
            "PrivacySandboxAdTopicsEnabled" = false;
            "PrivacySandboxPromptEnabled" = false;
            "PrivacySandboxSiteEnabledAdsEnabled" = false;

            # Permission defaults
            "DefaultGeolocationSetting" = 2;
            "DefaultNotificationsSetting" = 2;
            "DefaultWebBluetoothGuardSetting" = 2;
            "DefaultWebHidGuardSetting" = 2;
            "DefaultWebUsbGuardSetting" = 2;
            "PaymentMethodQueryEnabled" = false;
            "NetworkPredictionOptions" = 2;

            # AI features
            "GenAILocalFoundationalModelSettings" = 0;

            # HTTP allowlist for localhost development
            "InsecureContentAllowedForUrls" = [
              "http://localhost"
              "http://localhost:8001"
              "http://localhost:8080"
              "http://145.116.139.176"
            ];

            # First run experience
            "DefaultBrowserSettingEnabled" = false;
            "ImportAutofillFormData" = false;
            "ImportBookmarks" = false;
            "ImportHistory" = false;
            "ImportHomepage" = false;
            "ImportSavedPasswords" = false;
            "ImportSearchEngine" = false;

            # Search engine
            "DefaultSearchProviderEnabled" = true;
            "DefaultSearchProviderName" = "Kagi";
            "DefaultSearchProviderKeyword" = "@kg";
            "DefaultSearchProviderSearchURL" = "https://kagi.com/search?q={searchTerms}";
            "DefaultSearchProviderSuggestURL" = "https://kagi.com/api/autosuggest?q={searchTerms}";
            "DefaultSearchProviderIconURL" = "https://kagi.com/favicon.ico";
          };
        };

        home-manager.sharedModules = [
          (
            {
              pkgs,
              lib,
              ...
            }:
            {
              home.sessionVariables.BROWSER = "chromium";

              programs.chromium = {
                enable = true;
                package = pkgs.chromium;
              };

              # Link Claude Code native messaging manifest from google-chrome to chromium
              # Claude Code CLI generates the manifest in ~/.config/google-chrome but we use chromium
              # We need to override the home-manager managed symlink and create a real directory
              home.activation.setupNativeMessagingHosts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
                # Remove home-manager managed symlink
                if [ -L "$HOME/.config/chromium/NativeMessagingHosts" ]; then
                  echo "Removing home-manager managed NativeMessagingHosts symlink..."
                  rm "$HOME/.config/chromium/NativeMessagingHosts"
                fi

                # Create real directory
                mkdir -p "$HOME/.config/chromium/NativeMessagingHosts"
                mkdir -p "$HOME/.config/google-chrome/NativeMessagingHosts"

                # Link Bitwarden manifest from nix store
                BITWARDEN_MANIFEST=$(find ${pkgs.bitwarden-desktop} -name "*.json" -path "*/NativeMessagingHosts/*" 2>/dev/null | head -1)
                if [ -n "$BITWARDEN_MANIFEST" ] && [ -f "$BITWARDEN_MANIFEST" ]; then
                  ln -sf "$BITWARDEN_MANIFEST" "$HOME/.config/chromium/NativeMessagingHosts/$(basename "$BITWARDEN_MANIFEST")"
                fi

                # Link Claude manifest if it exists (will be generated by Claude Code on first run)
                CLAUDE_MANIFEST="$HOME/.config/google-chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json"
                if [ -f "$CLAUDE_MANIFEST" ]; then
                  echo "Linking Claude native messaging manifest to chromium..."
                  ln -sf "$CLAUDE_MANIFEST" "$HOME/.config/chromium/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json"
                fi
              '';

              settings.impermanence.homeDirectories = [
                ".config/chromium"
                ".config/google-chrome"
              ];
            }
          )
        ];
      };
    };
}
