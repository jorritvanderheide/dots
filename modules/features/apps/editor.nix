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
      cfg = config.settings.editor;
    in
    {
      options.settings.editor = {
        enable = lib.mkEnableOption "code editor";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            programs.vscode = {
              enable = true;

              package = pkgs.symlinkJoin {
                buildInputs = [ pkgs.makeWrapper ];
                meta.mainProgram = "code";
                paths = [ pkgs.vscode ];
                pname = pkgs.vscode.pname;
                version = pkgs.vscode.version;

                postBuild = ''
                  wrapProgram $out/bin/code --add-flags "--disable-chromium-warning-messages 2>/dev/null"
                '';
              };

              profiles.default = {
                enableExtensionUpdateCheck = false;
                enableUpdateCheck = false;

                extensions =
                  with pkgs.vscode-extensions;
                  [
                    bradlc.vscode-tailwindcss # Tailwind
                    esbenp.prettier-vscode # Prettier
                    jnoortheen.nix-ide # Nix IDE
                    mkhl.direnv # Direnv
                    tal7aouy.icons # Icons
                    vue.volar # Vue
                  ]
                  ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
                    {
                      name = "jjk";
                      publisher = "jjk";
                      version = "0.8.1";
                      sha256 = "sha256-2JUn6wkWgZKZzhitQy6v9R/rCNLrt7DBtt59707hp6c=";
                    }
                    {
                      name = "qt-core";
                      publisher = "theqtcompany";
                      version = "1.10.0";
                      sha256 = "sha256-jMXC9UqvVxlvNSAMoInv3wCKyDwL/1I0TbftYjJphdU=";
                    }
                    {
                      name = "qt-qml";
                      publisher = "theqtcompany";
                      version = "1.10.0";
                      sha256 = "sha256-5k80WTSDwdf3WeePUt2CgTd3dTejj0+fKnbjzNfMXng=";
                    }
                  ];

                userSettings = {
                  # AI
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
                        "command" = [ "nixfmt" ];
                      };
                    };
                  };
                  "nix.hiddenLanguageServerErrors" = [
                    "textDocument/definition"
                    "textDocument/documentHighlight"
                  ];

                  "[nix]" = {
                    "editor.defaultFormatter" = "jnoortheen.nix-ide";
                    "editor.formatOnSave" = true;
                  };

                  "[qml]" = {
                    "editor.defaultFormatter" = "theqtcompany.qt-qml";
                    "editor.formatOnSave" = true;
                  };

                  # Qt QML formatter settings
                  "qmlls.qmllint.disable" = false;
                  "qmlls.qmlformat.enable" = true;
                };
              };
            };

            home = {
              sessionVariables.EDITOR = "code --wait";

              packages = with pkgs; [
                nixd
                nixfmt
                qt6.qtdeclarative # for qmlformat
              ];
            };

            # Persist editor data across reboots
            settings.impermanence.homeDirectories = [
              ".config/Code"
            ];
          }
        ];
      };
    };
}
