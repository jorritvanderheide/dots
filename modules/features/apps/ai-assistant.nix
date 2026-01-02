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
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.ai-assistant requires features.impermanence to be enabled";
          }
        ];

        home-manager.sharedModules = [
          {
            programs.claude-code = {
              enable = true;

              settings = {
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

            features.impermanence.homeDirectories = [
              ".claude"
            ];
          }
        ];
      };
    };
}
