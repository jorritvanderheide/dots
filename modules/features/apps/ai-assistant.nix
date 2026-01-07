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
      cfg = config.features.ai-assistant;
    in
    {
      options.features.ai-assistant = {
        enable = lib.mkEnableOption "AI assistant applications";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
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

            features.impermanence = {
              homeDirectories = [
                ".claude"
              ];
              homeFiles = [
                ".claude.json"
              ];
            };
          }
        ];
      };
    };
}
