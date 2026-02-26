{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.prompt =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.prompt;
    in
    {
      options.settings.prompt = {
        enable = lib.mkEnableOption "Starship shell prompt";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          (
            {
              config,
              ...
            }:
            {
              programs.starship = {
                enable = true;
                enableFishIntegration = true;

                settings = {
                  add_newline = true;
                  format = "$hostname$username$directory$nix_shell$character";
                  line_break = true;

                  character = {
                    success_symbol = "[❯](bold green)";
                    error_symbol = "[❯](bold red)";
                  };

                  directory = {
                    read_only = " ";
                    repo_root_style = "bold white";
                  };

                  git_branch = {
                    style = "bold green";
                    symbol = "🌱 ";
                    truncation_length = 4;
                    truncation_symbol = "";
                  };

                  nix_shell = {
                    format = "via [Nix $symbol]($style) ";
                    style = "bold blue";
                    symbol = "❄️";
                  };

                }
                // lib.optionalAttrs config.programs.jujutsu.enable {
                  # Override format to include jj integration
                  format = lib.mkForce "$hostname$username$directory$custom$nix_shell$character";

                  custom = {
                    jj = {
                      command = "starship-jj --ignore-working-copy starship prompt";
                      format = "[$symbol](blue bold) $output ";
                      when = "jj root --ignore-working-copy";
                    };
                    git_branch = {
                      when = true;
                      command = "jj root >/dev/null 2>&1 || starship module git_branch";
                    };
                  };
                };
              };

              home = {
                packages = lib.optionals config.programs.jujutsu.enable [
                  inputs.starship-jj.packages.${pkgs.system}.default
                ];

                # Reduce logging
                sessionVariables.STARSHIP_LOG = "error";
              };

              # Add starship-jj configuration if jujutsu is enabled
              xdg.configFile."starship-jj/starship-jj.toml" = lib.mkIf config.programs.jujutsu.enable {
                text = ''
                  module_separator = " "
                  timeout = 1000

                  [bookmarks]
                  exclude = []
                  search_depth = 100

                  [[module]]
                  symbol = "🌱"
                  type = "Symbol"

                  [[module]]
                  color = "Green"
                  surround_with_quotes = false
                  type = "Bookmarks"

                  [[module]]
                  max_length = 24
                  surround_with_quotes = false
                  type = "Commit"
                '';
              };
            }
          )
        ];
      };
    };
}
