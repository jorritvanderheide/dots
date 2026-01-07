{
  lib,
  ...
}:
{
  flake.nixosModules.editor =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.features.editor;
    in
    {
      options.features.editor = {
        enable = lib.mkEnableOption "code editor";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            programs.vscode = {
              enable = true;

              profiles.default = {
                enableExtensionUpdateCheck = false;
                enableUpdateCheck = false;

                extensions =
                  with pkgs.vscode-extensions;
                  [
                    bradlc.vscode-tailwindcss
                    esbenp.prettier-vscode
                    jnoortheen.nix-ide
                    mkhl.direnv
                    tal7aouy.icons
                    vue.volar
                  ]
                  ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
                    {
                      name = "jjk";
                      publisher = "jjk";
                      version = "0.8.1";
                      sha256 = "sha256-2JUn6wkWgZKZzhitQy6v9R/rCNLrt7DBtt59707hp6c=";
                    }
                  ];

                userSettings = {
                  # AI/Chat
                  "chat.agent.enabled" = false;
                  "chat.commandCenter.enabled" = false;

                  # Editor
                  "editor.defaultFormatter" = "esbenp.prettier-vscode";
                  "editor.fontLigatures" = true;
                  "editor.formatOnPaste" = true;
                  "editor.formatOnSave" = false;
                  "editor.wordWrap" = "on";

                  # Extensions
                  "extensions.ignoreRecommendations" = true;

                  # Git
                  "git.autofetch" = true;
                  "git.confirmSync" = false;
                  "git.enableCommitSigning" = true;
                  "git.openRepositoryInParentFolders" = "always";
                  "git.suggestSmartCommit" = false;

                  # Search
                  "search.exclude" = {
                    "**/.direnv" = true;
                    "**/node_modules" = true;
                  };

                  # Telemetry
                  "telemetry.editStats.enabled" = false;
                  "telemetry.feedback.enabled" = false;
                  "telemetry.telemetryLevel" = "off";

                  # Terminal
                  "terminal.external.linuxExec" = "ghostty"; # TODO
                  "terminal.integrated.defaultProfile.linux" = "fish";
                  "terminal.integrated.enablePersistentSessions" = false;
                  "terminal.integrated.fontFamily" = "JetBrains Mono Nerd Font Mono";
                  "terminal.integrated.fontLigatures.enabled" = true;

                  # Updates
                  "update.showReleaseNotes" = false;

                  # Window
                  "window.commandCenter" = true;
                  "window.menuBarVisibility" = "toggle";
                  "window.restoreWindows" = "none";
                  "window.titleBarStyle" = "custom";

                  # Workbench
                  "workbench.activityBar.location" = "hidden";
                  "workbench.editor.editorActionsLocation" = "hidden";
                  "workbench.layoutControl.enabled" = false;
                  "workbench.startupEditor" = "none";

                  # Nix IDE
                  "nix.enableLanguageServer" = true;
                  "nix.serverPath" = "nixd";
                  "nix.serverSettings" = {
                    "nixd" = {
                      "formatting" = {
                        "command" = [
                          "nixfmt"
                        ];
                      };
                    };
                  };
                  "nix.hiddenLanguageServerErrors" = [
                    "textDocument/definition"
                    "textDocument/documentHighlight"
                    "textDocument/formatting"
                  ];

                  "[nix]" = {
                    "editor.defaultFormatter" = "jnoortheen.nix-ide";
                  };
                };
              };
            };

            home = {
              sessionVariables.EDITOR = "code";

              packages = with pkgs; [
                nixd
                nixfmt
              ];
            };

            # Persist editor data across reboots
            features.impermanence.homeDirectories = [
              ".config/Code"
            ];
          }
        ];
      };
    };
}
