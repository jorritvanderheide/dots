{
  lib,
  ...
}:
{
  flake.nixosModules.app-launch =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.app-launch;
    in
    {
      options.settings.app-launch = {
        enable = lib.mkEnableOption "app2unit application launcher";
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = with pkgs; [
          app2unit
        ];

        environment.sessionVariables = {
          APP2UNIT_SLICES = "a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice";
          APP2UNIT_TYPE = "service";
        };
      };
    };
}
