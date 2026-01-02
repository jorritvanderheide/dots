{
  lib,
  ...
}:
{
  flake.nixosModules.prompt =
    {
      config,
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
          {
            home.sessionVariables.STARSHIP_LOG = "error";

            programs.starship = {
              enable = true;

              settings = {
                format = lib.mkForce "$hostname$username$directory$nix_shell$character";
              };
            };
          }
        ];
      };
    };
}
