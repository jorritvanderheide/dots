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
                signingKey = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH public key for commit signing (from Bitwarden)";
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
                      gpg.ssh.allowedSignersFile = "~/.ssh/allowedSigners";
                      init.defaultBranch = "trunk";
                      safe.directory = [ "/etc/nixos" ];

                      user = {
                        name = cfg.userName;
                        email = cfg.userEmail;
                      };

                    };

                    signing = {
                      format = "ssh";
                      key = cfg.signingKey;
                      signByDefault = true;
                    };
                  };
                };

                 # Create SSH allowedSigners file for commit verification
                home.file.".ssh/allowedSigners".text = ''
                  ${cfg.userEmail} ${cfg.signingKey}
                '';

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
