{
  lib,
  ...
}:
{
  flake.nixosModules.ai-assistant =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.ai-assistant;
    in
    {
      options.settings.ai-assistant = {
        enable = lib.mkEnableOption "Claude Code AI assistant";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation = {
          homeDirectories = [
            ".claude"
          ];

          homeFiles = [
            ".claude.json"
          ];
        };

        home-manager.sharedModules = [
          (
            { pkgs, ... }:
            {
              programs.claude-code = {
                enable = true;

                settings = {
                  gitAttribution = false;
                  includeCoAuthoredBy = false;
                  preferredEditor = "code";
                  shellIntegration = true;

                  experimental = {
                    enableParallelToolUse = true;
                  };

                  ui = {
                    theme = "auto";
                    compactMode = false;
                  };
                };
              };

              # Wrapper for claude that fixes the native host shebang after running --chrome
              home.packages = [
                pkgs.nodejs_24 # Required for Claude in Chrome MCP server

                (pkgs.writeShellScriptBin "claude-wrapped" ''
                  # Get the real claude binary from programs.claude-code
                  CLAUDE_BIN="${pkgs.claude-code}/bin/claude"

                  # Run the original claude command with all arguments
                  "$CLAUDE_BIN" "$@"
                  EXIT_CODE=$?

                  # If --chrome flag was used, fix the native host shebang
                  if [[ " $* " == *" --chrome"* ]]; then
                    NATIVE_HOST="$HOME/.claude/chrome/chrome-native-host"
                    if [ -f "$NATIVE_HOST" ]; then
                      # Check if the shebang is the problematic #!/bin/bash
                      if head -1 "$NATIVE_HOST" | grep -q '^#!/bin/bash$'; then
                        echo "Fixing Claude native host shebang for NixOS..."
                        sed -i '1s|^#!/bin/bash$|#!/usr/bin/env bash|' "$NATIVE_HOST"
                        chmod +x "$NATIVE_HOST"
                      fi
                    fi
                  fi

                  exit $EXIT_CODE
                '')
              ];

              # Create an alias so 'claude' uses the wrapper
              home.shellAliases = {
                claude = "claude-wrapped";
              };

            }
          )
        ];
      };
    };
}
