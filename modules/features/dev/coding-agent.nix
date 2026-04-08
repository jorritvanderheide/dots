{
  flake.nixosModules.coding-agent = {
    config = {
      home-manager.sharedModules = [
        {
          home.file = {
            ".config/opencode/agents/code-reviewer.md".text = ''
              ---
              description: Reviews pull requests for code quality, bugs, and best practices
              mode: subagent
              tools:
                write: false
                edit: false
                bash: false
              temperature: 0.1
              ---
              You are a code reviewer. Your role is to thoroughly review pull requests and provide constructive feedback.

              ## Review Focus
              - **Bugs and logic errors**: Look for potential runtime errors, edge cases, and incorrect logic
              - **Security issues**: Identify vulnerabilities, exposed secrets, or unsafe patterns
              - **Code quality**: Check for readability, complexity, and maintainability
              - **Best practices**: Verify adherence to project conventions and idiomatic patterns
              - **Performance**: Identify inefficient algorithms, unnecessary computations, or memory issues

              ## Output Format
              Present findings organized by file in a format suitable for PR comments:
              - Use markdown
              - Include code snippets with line numbers when relevant
              - Rate severity: 🔴 Critical, 🟡 Warning, 💡 Suggestion

              ## Guidelines
              - Be constructive and helpful, not condescending
              - Explain WHY something is an issue, not just WHAT is wrong
              - Suggest improvements when possible
              - If code is unclear, ask for clarification rather than assuming
              - Do NOT make any changes - only suggest and explain
            '';

            ".config/opencode/commands/review.md".text = ''
              ---
              description: Review a PR branch in a new worktree using worktrunk
              ---
              @code-reviewer Review the branch "$ARGUMENTS" for a pull request.

              First, create a worktree using worktrunk:
              ```
              wt switch --create review-$ARGUMENTS
              ```
              Then review all changes thoroughly and output findings in a copy-pasteable format for PR comments.

              When done, tell me the branch name (review-<branchname>) so I can clean it up later.
            '';

            ".config/opencode/commands/cleanup.md".text = ''
              ---
              description: Remove a PR review worktree using worktrunk
              ---
              Remove the worktree for branch "review-$ARGUMENTS":
              ```
              wt switch main
              wt remove review-$ARGUMENTS --force
              ```
              Confirm the worktree was removed.
            '';

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

          programs.opencode.enable = true;

          programs.claude-code = {
            enable = true;
            settings.includeCoAuthoredBy = false;
          };
        }
      ];

      my.preservation = {
        homeDirectories = [
          ".claude"
          ".config/opencode"
        ];
      };
    };
  };
}
