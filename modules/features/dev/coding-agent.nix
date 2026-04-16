{
  flake.nixosModules.coding-agent =
    {
      pkgs,
      ...
    }:
    let
      claudeStatusLine = pkgs.writeShellApplication {
        name = "claude-statusline";
        runtimeInputs = with pkgs; [
          coreutils
          git
          jq
          jujutsu
        ];
        text = ''
          input=$(cat)
          cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd')
          model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id')
          dir=$(basename "$cwd")
          vcs=""
          if jj_out=$(jj --no-pager --repository "$cwd" log -r @ --no-graph -T 'if(bookmarks, bookmarks, change_id.short())' 2>/dev/null); then
            vcs=$jj_out
          elif git_out=$(git -C "$cwd" branch --show-current 2>/dev/null) && [ -n "$git_out" ]; then
            vcs=$git_out
          fi
          if [ -n "$vcs" ]; then
            printf '%s · %s · %s' "$dir" "$vcs" "$model"
          else
            printf '%s · %s' "$dir" "$model"
          fi
        '';
      };
    in
    {
      config = {
        # Ollama for local LLM inference
        services.ollama = {
          enable = true;
          environmentVariables.OLLAMA_NUM_CTX = "32768";
        };

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

            programs.opencode = {
              enable = true;
              settings.provider.ollama-local = {
                npm = "@ai-sdk/openai-compatible";
                name = "Ollama (local)";
                options.baseURL = "http://localhost:11434/v1";
                models."qwen3:8b-32k" = {
                  tools = true;
                  context_length = 32768;
                };
                models."qwen3:14b-32k" = {
                  tools = true;
                  context_length = 32768;
                };
              };
            };

            programs.claude-code = {
              enable = true;

              settings = {
                includeCoAuthoredBy = false;

                statusLine = {
                  type = "command";
                  command = "${claudeStatusLine}/bin/claude-statusline";
                };

                # Curated pre-allows for read-only / evaluation-only commands.
                # Anything that mutates state still prompts. Commands with
                # destructive flag modes (find -delete, sed -i, tar, cp, mv, rm)
                # are intentionally omitted.
                permissions.allow = [
                  # Filesystem inspection (read-only)
                  "Bash(ls:*)"
                  "Bash(cat:*)"
                  "Bash(head:*)"
                  "Bash(tail:*)"
                  "Bash(wc:*)"
                  "Bash(file:*)"
                  "Bash(stat:*)"
                  "Bash(du:*)"
                  "Bash(df:*)"
                  "Bash(pwd:*)"
                  "Bash(basename:*)"
                  "Bash(dirname:*)"
                  "Bash(readlink:*)"
                  "Bash(realpath:*)"
                  "Bash(tree:*)"
                  "Bash(diff:*)"

                  # Text pipelines (read-only; no in-place edits)
                  "Bash(sort:*)"
                  "Bash(uniq:*)"
                  "Bash(cut:*)"
                  "Bash(tr:*)"
                  "Bash(rev:*)"
                  "Bash(tac:*)"
                  "Bash(nl:*)"
                  "Bash(column:*)"
                  "Bash(xxd:*)"
                  "Bash(strings:*)"
                  "Bash(jq:*)"

                  # Search
                  "Bash(grep:*)"
                  "Bash(rg:*)"
                  "Bash(fd:*)"

                  # Hashes (read-only)
                  "Bash(md5sum:*)"
                  "Bash(sha256sum:*)"
                  "Bash(sha512sum:*)"

                  # System / process / env inspection
                  "Bash(ps:*)"
                  "Bash(pgrep:*)"
                  "Bash(pstree:*)"
                  "Bash(free:*)"
                  "Bash(uptime:*)"
                  "Bash(whoami:*)"
                  "Bash(id:*)"
                  "Bash(date:*)"
                  "Bash(uname:*)"
                  "Bash(hostname:*)"
                  "Bash(which:*)"
                  "Bash(type:*)"
                  "Bash(env:*)"
                  "Bash(printenv:*)"
                  "Bash(lsof:*)"
                  "Bash(ss:*)"

                  # systemd inspection
                  "Bash(systemctl status:*)"
                  "Bash(systemctl list-units:*)"
                  "Bash(systemctl is-active:*)"
                  "Bash(systemctl is-enabled:*)"
                  "Bash(systemctl cat:*)"
                  "Bash(journalctl:*)"

                  # Jujutsu (read-only)
                  "Bash(jj status:*)"
                  "Bash(jj st:*)"
                  "Bash(jj log:*)"
                  "Bash(jj l:*)"
                  "Bash(jj diff:*)"
                  "Bash(jj show:*)"
                  "Bash(jj op log:*)"
                  "Bash(jj bookmark list:*)"

                  # Git (read-only)
                  "Bash(git status:*)"
                  "Bash(git log:*)"
                  "Bash(git diff:*)"
                  "Bash(git show:*)"
                  "Bash(git blame:*)"
                  "Bash(git remote -v:*)"

                  # GitHub CLI (read-only subcommands)
                  "Bash(gh pr list:*)"
                  "Bash(gh pr view:*)"
                  "Bash(gh pr diff:*)"
                  "Bash(gh issue list:*)"
                  "Bash(gh issue view:*)"
                  "Bash(gh run list:*)"
                  "Bash(gh run view:*)"

                  # Nix (evaluation / syntax / dry-run only)
                  "Bash(nix-instantiate --parse:*)"
                  "Bash(nix flake check:*)"
                  "Bash(nix flake show:*)"
                  "Bash(nix flake metadata:*)"
                  "Bash(nix eval:*)"
                  "Bash(nix-store -q:*)"
                  "Bash(nix why-depends:*)"
                  "Bash(nixos-option:*)"
                  "Bash(nixos-rebuild dry-build:*)"
                  "Bash(nixos-rebuild dry-activate:*)"
                ];
              };

              # Context7 MCP: up-to-date library docs on demand.
              # Free tier works unauthenticated; add CONTEXT7_API_KEY header for higher limits.
              mcpServers.context7 = {
                type = "http";
                url = "https://mcp.context7.com/mcp";
              };

              # Global CLAUDE.md, applied to every Claude Code session.
              # Karpathy behavioral guidelines source: https://github.com/forrestchang/andrej-karpathy-skills (MIT)
              context = ''
                # CLAUDE.md

                ## User preferences

                - **Version control:** use `jj` (jujutsu), not `git`, unless explicitly told otherwise or the operation has no jj equivalent. Examples: `jj st` over `git status`, `jj log` over `git log`, `jj diff` over `git diff`, `jj show` over `git show`. The repo is colocated, so git commands still work for read-only inspection, but prefer jj.
                - **No em dashes in prose.** The user dislikes em dashes (`—`) used to split sentences because they read as AI-generated. Use a period, comma, semicolon, or parentheses instead. This applies to chat responses, commit messages, PR descriptions, and any other prose written for the user. Inside quoted source text (documentation, upstream content) leave existing em dashes alone.

                ---

                ## Behavioral guidelines

                Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

                **Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

                ## 1. Think Before Coding

                **Don't assume. Don't hide confusion. Surface tradeoffs.**

                Before implementing:
                - State your assumptions explicitly. If uncertain, ask.
                - If multiple interpretations exist, present them - don't pick silently.
                - If a simpler approach exists, say so. Push back when warranted.
                - If something is unclear, stop. Name what's confusing. Ask.

                ## 2. Simplicity First

                **Minimum code that solves the problem. Nothing speculative.**

                - No features beyond what was asked.
                - No abstractions for single-use code.
                - No "flexibility" or "configurability" that wasn't requested.
                - No error handling for impossible scenarios.
                - If you write 200 lines and it could be 50, rewrite it.

                Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

                ## 3. Surgical Changes

                **Touch only what you must. Clean up only your own mess.**

                When editing existing code:
                - Don't "improve" adjacent code, comments, or formatting.
                - Don't refactor things that aren't broken.
                - Match existing style, even if you'd do it differently.
                - If you notice unrelated dead code, mention it - don't delete it.

                When your changes create orphans:
                - Remove imports/variables/functions that YOUR changes made unused.
                - Don't remove pre-existing dead code unless asked.

                The test: Every changed line should trace directly to the user's request.

                ## 4. Goal-Driven Execution

                **Define success criteria. Loop until verified.**

                Transform tasks into verifiable goals:
                - "Add validation" → "Write tests for invalid inputs, then make them pass"
                - "Fix the bug" → "Write a test that reproduces it, then make it pass"
                - "Refactor X" → "Ensure tests pass before and after"

                For multi-step tasks, state a brief plan:
                ```
                1. [Step] → verify: [check]
                2. [Step] → verify: [check]
                3. [Step] → verify: [check]
                ```

                Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

                ---

                **These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
              '';
            };
          }
        ];

        my.preservation = {
          homeFiles = [
            ".claude.json"
          ];

          homeDirectories = [
            ".claude"
            ".config/opencode"
          ];

          systemDirectories = [
            {
              directory = "/var/lib/private/ollama";
              user = "ollama";
              group = "ollama";
            }
          ];
        };
      };
    };
}
