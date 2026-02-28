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
          {
            home.file = {
              ".claude/CLAUDE.md".text = ''
                # Global Claude Instructions

                ## Obsidian Knowledge Vault

                You have permanent read and write access to `/home/jorrit/Git/obsidian/`.

                Programming notes go in `/home/jorrit/Git/obsidian/Coding/`.

                When writing atomic notes (via `/note` or when asked), use this format:

                ```markdown
                ---
                tags: [programming, <specific-topic>]
                date: <YYYY-MM-DD>
                ---
                # <Concept Name>

                <One sentence: what this is.>

                ## Why it matters

                <2-3 sentences on when/why you'd reach for this.>

                ## Example

                <Minimal concrete code example or illustration.>

                ## Related

                - [[Related Concept]]
                ```

                Rules for atomic notes:
                - One concept per file, filename = concept name (e.g. `Nix Derivations.md`)
                - Prefer linking to existing notes with `[[WikiLinks]]` over repeating content
                - Do not create a note for every interaction — only when a genuinely reusable concept was encountered
              '';

              ".claude/commands/note.md".text = ''
                Look at what we discussed in this conversation and identify any programming concepts worth capturing as permanent knowledge.

                For each reusable concept (not task-specific details), create an atomic note in `/home/jorrit/Git/obsidian/Coding/` following the format in CLAUDE.md:
                - One concept per file
                - Filename = concept name (e.g. `Nix Flake Outputs.md`)
                - Use frontmatter with tags and date
                - Link to related existing notes using [[WikiLinks]] where relevant

                First list the existing notes in `/home/jorrit/Git/obsidian/Coding/` so you can link to them and avoid duplicates. Then write only notes for concepts that are genuinely reusable and not already covered.

                Tell me which notes you created and why each concept was worth capturing.
              '';
            };

            programs.claude-code = {
              enable = true;

              settings = {
                experimental.enableParallelToolUse = true;
                gitAttribution = false;
                includeCoAuthoredBy = false;
                preferredEditor = "code";
                shellIntegration = true;

                ui = {
                  theme = "auto";
                  compactMode = false;
                };

                hooks.SessionStart = [
                  {
                    hooks = [
                      {
                        type = "command";
                        command = "/home/jorrit/.claude/plugins/marketplaces/claude-plugins-official/plugins/learning-output-style/hooks-handlers/session-start.sh";
                      }
                    ];
                  }
                ];
              };
            };
          }
        ];
      };
    };
}
