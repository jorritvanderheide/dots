{
  flake.nixosModules.coding-agent = {
    config = {
      home-manager.sharedModules = [
        {
          home.file = {
            ".config/opencode/skills/note/SKILL.md".text = ''
              ---
              name: note
              description: Capture programming concepts as permanent knowledge notes in Obsidian
              ---
              # Note Skill

              Capture reusable programming concepts from this conversation into Obsidian notes.

              ## When to Use
              - User asks to save something as a note
              - User mentions wanting to remember something
              - A reusable concept is discovered that should be preserved

              ## Process

              1. First, glob `*.md` files in `/home/jorrit/Git/obsidian/Notes/` to avoid duplicates
              2. Identify reusable concepts (NOT task-specific details)
              3. If multiple candidates, use AskUserQuestion to let user select
              4. For each concept:
                 - Create file: `/home/jorrit/Git/obsidian/Notes/<Concept Name>.md`
                 - Use sentence case for filename
                 - Include [[WikiLinks]] to related existing notes
                 - Write in atomic, reusable format
              5. Tell user which notes were created and why each is valuable
            '';
          };

          programs.opencode = {
            enable = true;

            settings = {
              "$schema" = "https://opencode.ai/config.json";
              theme = "stylix";
            };
          };
        }
      ];

      my.preservation = {
        homeDirectories = [
          ".config/opencode"
        ];
      };
    };
  };
}
