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
      cfg = config.settings.git;
    in
    {
      options.settings.git = {
        enable = lib.mkEnableOption "Git and Jujutsu";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          (
            { config, ... }:
            let
              cfg = config.settings.git;
            in
            {
              options.settings.git = {
                allowedSigningKeys = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Allowed keys for commit signing";
                };

                signingKey = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH public key for commit signing";
                };

                userEmail = lib.mkOption {
                  type = lib.types.str;
                  description = "Git user email";
                };

                userName = lib.mkOption {
                  type = lib.types.str;
                  description = "Git user name";
                };
              };

              config = {
                programs = {
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

                  jujutsu = {
                    enable = true;

                    settings = {
                      # TODO: Enable commit signing when jujutsu supports getting the priva key from the Bitwarden ssh-agent
                      # signing = {
                      #   backend = "ssh";
                      #   backends.ssh.allowed-signers = "~/.ssh/allowedSigners";
                      #   behavior = "own";
                      #   key = cfg.signingKey;
                      # };

                      user = {
                        name = cfg.userName;
                        email = cfg.userEmail;
                      };
                    };
                  };
                };

                # Persist Git directory
                settings.impermanence.homeDirectories = [
                  "Git"
                ];

                # Create SSH allowedSigners file for commit verification
                home.file.".ssh/allowedSigners".text = ''
                  ${builtins.concatStringsSep "\n" cfg.allowedSigningKeys}
                '';
              };
            }
          )
        ];
      };
    };
}
