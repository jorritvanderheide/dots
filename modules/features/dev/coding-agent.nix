{
  lib,
  ...
}:
{
  flake.nixosModules.coding-agent =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.coding-agent;
    in
    {
      options.settings.coding-agent = {
        enable = lib.mkEnableOption "OpenCode AI coding agent";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation = {
          homeDirectories = [
            ".claude"
            ".config/opencode"
          ];

          homeFiles = [
            ".claude.json"
          ];
        };

        home-manager.sharedModules = [
          {
            home.file = {
              ".claude/commands/note.md".text = ''
                Look at what we discussed in this conversation and identify any programming concepts worth capturing as permanent knowledge.

                First, list the existing notes in `/home/jorrit/Git/obsidian/Notes/` to avoid duplicates and find linking opportunities.

                Then, identify all reusable concepts from this conversation (not task-specific details). If there are multiple candidates, use the AskUserQuestion tool to present them as a multiselect question — ask "Which concepts should I capture as notes?" with one option per concept, including a brief description of what the note would cover. Only proceed with the concepts the user selects.

                For each selected concept, create an atomic note in `/home/jorrit/Git/obsidian/Notes/` following the format in CLAUDE.md:
                - One concept per file
                - Filename = concept name in sentence case (e.g. `Nix flake outputs.md`)
                - Link to related existing notes using [[WikiLinks]] where relevant
                - Create the note(s) using Obsidian CLI: `obsidian create path="Notes" name="<Concept name>" template="Capture AI" open`

                Tell me which notes you created and why each concept was worth capturing.
              '';
            };

            programs = {
              claude-code = {
                enable = true;

                settings = {
                  experimental.enableParallelToolUse = true;
                  gitAttribution = false;
                  includeCoAuthoredBy = false;
                  preferredEditor = "zeditor";
                  shellIntegration = true;

                  ui = {
                    theme = "auto";
                    compactMode = false;
                  };

                  permissions.allow = [
                    "Read(/home/jorrit/Git/obsidian/**)"
                    "Write(/home/jorrit/Git/obsidian/**)"
                    "Edit(/home/jorrit/Git/obsidian/**)"
                    "Bash(ls /home/jorrit/Git/obsidian/**)"
                    "Glob(/home/jorrit/Git/obsidian/**)"
                  ];
                };
              };

              opencode = {
                enable = true;

                settings = {
                  "$schema" = "https://opencode.ai/config.json";
                  theme = "stylix";

                  provider.ollama = {
                    name = "Ollama (local)";
                    npm = "@ai-sdk/openai-compatible";

                    models = {
                      # "qwen3-coder" = {
                      #   name = "Qwen3-coder 30B";
                      #   tools = true;
                      # };
                    };

                    options = {
                      baseURL = "http://localhost:11434/v1";
                    };
                  };
                };
              };
            };
          }
        ];
      };
    };
}
