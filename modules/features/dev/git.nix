{
  lib,
  ...
}:
{
  flake.nixosModules.git =
    {
      config,
      ...
    }:
    let
      cfg = config.features.git;
    in
    {
      options.features.git = {
        enable = lib.mkEnableOption "Git and Jujutsu";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.git requires features.impermanence to be enabled";
          }
        ];

        home-manager.sharedModules = [
          (
            { config, ... }:
            let
              cfg = config.features.git;
            in
            {
              options.features.git = {
                userName = lib.mkOption {
                  type = lib.types.str;
                  description = "Git user name";
                };
                userEmail = lib.mkOption {
                  type = lib.types.str;
                  description = "Git user email";
                };
              };

              config = {
                programs = {
                  jujutsu = {
                    enable = true;

                    settings.user = {
                      name = cfg.userName;
                      email = cfg.userEmail;
                    };
                  };

                  git = {
                    enable = true;

                    ignores = [
                      ".direnv/"
                      "result/"
                    ];

                    settings = {
                      init.defaultBranch = "trunk";
                      safe.directory = [ "/etc/nixos" ];

                      user = {
                        name = cfg.userName;
                        email = cfg.userEmail;
                      };
                    };
                  };
                };

                features.impermanence.homeDirectories = [
                  "Git"
                ];
              };
            }
          )
        ];
      };
    };
}
