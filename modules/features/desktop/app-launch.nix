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
      cfg = config.features.app-launch;
    in
    {
      options.features.app-launch = {
        enable = lib.mkEnableOption "application launcher with systemd integration";
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
