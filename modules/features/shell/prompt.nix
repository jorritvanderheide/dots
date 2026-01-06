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
      cfg = config.features.prompt;
    in
    {
      options.features.prompt = {
        enable = lib.mkEnableOption "shell prompt (Starship)";
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
                      when = "! jj root >/dev/null 2>&1";
                      command = "starship module git_branch";
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
              xdg.configFile."starship-jj.toml" = lib.mkIf config.programs.jujutsu.enable {
                text = ''
                  module_separator = " "
                  timeout = 1000

                  [bookmarks]
                  search_depth = 100
                  exclude = []

                  [[module]]
                  type = "Bookmarks"
                  separator = " "
                  color = "Green"

                  [[module]]
                  type = "Commit"
                  max_length = 24

                  [[module]]
                  type = "State"
                  separator = " "
                '';
              };
            }
          )
        ];
      };
    };
}
