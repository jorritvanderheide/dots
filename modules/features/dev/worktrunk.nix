{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.worktrunk =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.worktrunk;
    in
    {
      options.settings.worktrunk = {
        enable = lib.mkEnableOption "worktrunk git worktree manager";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          inputs.worktrunk.homeModules.default
          {
            programs.worktrunk = {
              enable = true;
              enableFishIntegration = true;
            };
          }
        ];
      };
    };
}
