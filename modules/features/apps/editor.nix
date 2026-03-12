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
        enable = lib.mkEnableOption "VS Code editor";
      };

      config = lib.mkIf cfg.enable {
        programs.nix-ld.enable = true;

        home-manager.sharedModules = [
          {
            programs.vscode = {
              enable = true;

              package = pkgs.symlinkJoin {
                buildInputs = [ pkgs.makeWrapper ];
                meta.mainProgram = "code";
                paths = [ pkgs.vscode ];
                inherit (pkgs.vscode) pname version;

                postBuild = ''
                  wrapProgram $out/bin/code --add-flags "--disable-chromium-warning-messages 2>/dev/null"
                '';
              };

              profiles.default = {
                enableExtensionUpdateCheck = false;
                enableUpdateCheck = false;

                extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
                  {
                    name = "claude-code";
                    publisher = "anthropic";
                    version = "latest";
                    sha256 = "sha256-9/k1hnMpDl6dTlG67e37JuNo7mKtXAsLQpX2E0fbFuM=";
                  }
                  {
                    name = "direnv";
                    publisher = "mkhl";
                    version = "latest";
                    sha256 = "sha256-9sFcfTMeLBGw2ET1snqQ6Uk//D/vcD9AVsZfnUNrWNg=";
                  }
                  {
                    name = "icons";
                    publisher = "tal7aouy";
                    version = "latest";
                    sha256 = "sha256-PdhNFyVUWcOfli/ZlT+6TmtWrV31fBP1E1Vd4QWOY+A=";
                  }
                  {
                    name = "jjk";
                    publisher = "jjk";
                    version = "latest";
                    sha256 = "sha256-2JUn6wkWgZKZzhitQy6v9R/rCNLrt7DBtt59707hp6c=";
                  }
                  {
                    name = "markdown-preview-enhanced";
                    publisher = "shd101wyy";
                    version = "latest";
                    sha256 = "sha256-+dwLuqtEYirQaw/tuG5m5Ugk0crKQQZM43TmslJsBBc=";
                  }
                  {
                    name = "nix-ide";
                    publisher = "jnoortheen";
                    version = "latest";
                    sha256 = "sha256-epdEMPAkSo0IXsd+ozicI8bjPPquDKIzB3ONRUYWwn8=";
                  }
                  {
                    name = "qt-core";
                    publisher = "theqtcompany";
                    version = "latest";
                    sha256 = "sha256-/SAoJmKfOfLtbYn4jvtbAFIa6O7kDouv0xQVhnxFOKM=";
                  }
                  {
                    name = "prettier-vscode";
                    publisher = "esbenp";
                    version = "latest";
                    sha256 = "sha256-Zi5ihki/risHm75ERQxUgqhiTbpM6fknHLMCAkXrEVo=";
                  }
                  {
                    name = "qt-qml";
                    publisher = "theqtcompany";
                    version = "latest";
                    sha256 = "sha256-WPzierXLQM+HdVb0XAx80f4Fdd34Vf7WbFzFapr5VHE=";
                  }
                  {
                    name = "regionmarker";
                    publisher = "awwsky";
                    version = "latest";
                    sha256 = "sha256-khqL7H3o7Q3KKQsB+CZ7duDQLHgPQzJHspnqL/zEwS5=";
                  }
                  {
                    name = "todo-tree";
                    publisher = "gruntfuggly";
                    version = "latest";
                    sha256 = "sha256-Fj9cw+VJ2jkTGUclB1TLvURhzQsaryFQs/+f2RZOLHs=";
                  }
                  {
                    name = "volar";
                    publisher = "vue";
                    version = "latest";
                    sha256 = "sha256-69r7DOwCORy1KFqVOT3HPKwhFgrTahbYqc3e3XorouM=";
                  }
                  {
                    name = "vscode-tailwindcss";
                    publisher = "bradlc";
                    version = "latest";
                    sha256 = "sha256-58/yM4xP8ewpegNlVSWnyFIoAmEd7E/CigQgae7OgZY=";
                  }
                ];

                keybindings = [
                  # Toggle Todo-tree
                  {
                    key = "ctrl+shift+u";
                    command = "workbench.view.extension.todo-tree-container";
                  }

                  # Open Claude in sidebar
                  {
                    key = "ctrl+alt+i";
                    command = "claude-vscode.sidebar.open";
                  }

                  # Toggle sidebars
                  {
                    key = "ctrl+[";
                    command = "workbench.action.toggleSidebarVisibility";
                  }
                  {
                    key = "ctrl+]";
                    command = "workbench.action.toggleAuxiliaryBar";
                  }
                ];

                userSettings = {
                  # AI
                  "chat.agent.enabled" = false;
                  "chat.commandCenter.enabled" = false;
                  "chat.disableAIFeatures" = true;
                  "chat.fontSize" = "15.333333333333334";
                  "claudeCode.preferredLocation" = "sidebar";
                  "claudeCode.claudeProcessWrapper" = "/etc/profiles/per-user/jorrit/bin/claude";

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
                  "terminal.external.linuxExec" = "ghostty";
                  "terminal.integrated.defaultProfile.linux" = "fish";
                  "terminal.integrated.enablePersistentSessions" = false;
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

                  "nix.hiddenLanguageServerErrors" = [
                    "textDocument/definition"
                  ];

                  "nix.serverSettings" = {
                    "nixd" = {
                      "formatting" = {
                        "command" = [ "nixfmt" ];
                      };
                      "nixpkgs" = {
                        "expr" = "import <nixpkgs> {}";
                      };
                      "options" = {
                        "nixos" = {
                          "expr" = "(builtins.getFlake \"/etc/nixos\").nixosConfigurations.rocinante.options";
                        };
                        "home-manager" = {
                          "expr" =
                            "(builtins.getFlake \"/etc/nixos\").nixosConfigurations.rocinante.options.home-manager.users.type.getSubOptions []";
                        };
                      };
                    };
                  };

                  # JavaScript/TypesScript
                  "javascript.preferences.importModuleSpecifier" = "non-relative";
                  "typescript.preferences.importModuleSpecifier" = "non-relative";
                  "typescript.updateImportsOnFileMove.enabled" = "always";

                  # Nix
                  "[nix]" = {
                    "editor.defaultFormatter" = "jnoortheen.nix-ide";
                    "editor.formatOnSave" = true;
                  };

                  "[qml]" = {
                    "editor.defaultFormatter" = "theqtcompany.qt-qml";
                    "editor.formatOnSave" = true;
                  };

                  # Qt QML
                  "qt-qml.doNotAskForQmllsDownload" = true;
                  "qt-qml.qmlls.customExePath" = "${pkgs.qt6.qtdeclarative}/bin/qmlls";

                  "qt-qml.qmlls.additionalImportPaths" = [
                    "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
                    "/run/current-system/sw/lib/qt-6/qml"
                  ];

                  # Vue
                  "[vue]" = {
                    "editor.formatOnPaste" = true;
                    "editor.formatOnSave" = true;
                  };
                };
              };
            };

            programs.zed-editor = {
              enable = true;

              extensions = [
                "nix"
                "vue"
              ];

              userSettings = {
                auto_update = false;
                base_keymap = "VSCode";
                hour_format = "hour24";
                load_direnv = "shell_hook";
                vim_mode = false;

                lsp = {
                  nix = {
                    binary = {
                      path_lookup = true;
                    };
                  };
                };

                nix = {
                  binary = {
                    path_lookup = true;
                  };
                };

                theme = lib.mkForce {
                  mode = "system";
                  dark = "Catppuccin";
                };
              };
            };

            home = {
              sessionVariables.EDITOR = "zed --wait";

              packages = with pkgs; [
                nixd
                nixfmt
                qt6.qtdeclarative # For qmlformat
              ];
            };
          }
        ];

        # Persist editor data across reboots
        settings.preservation.homeDirectories = [
          ".config/Code"
          ".config/zed"
          ".local/share/zed"
        ];
      };
    };
}
