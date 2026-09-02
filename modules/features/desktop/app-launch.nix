{
  flake.nixosModules.app-launch =
    {
      lib,
      pkgs,
      ...
    }:
    {
      options.my.app-launch.enable = lib.mkOption {
        description = "Whether the app-launch module (provides the app2unit launcher) is imported. Read-only marker for other modules to assert this dependency on.";
        readOnly = true;
        type = lib.types.bool;
      };

      config = {
        my.app-launch.enable = true;

        environment = {
          sessionVariables = {
            APP2UNIT_SLICES = "a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice";
            APP2UNIT_TYPE = "service";
          };

          systemPackages = with pkgs; [
            app2unit
          ];
        };
      };
    };
}
