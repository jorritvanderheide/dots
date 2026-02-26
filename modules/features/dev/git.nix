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
        # Persist Git directory
        settings.preservation.homeDirectories = [
          "Git"
        ];

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
                  description = "Allowed SSH public keys for commit signature verification";
                };

                signingKey = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH public key used to sign commits";
                };

                userEmail = lib.mkOption {
                  type = lib.types.str;
                  description = "Email address for Git commits";
                };

                userName = lib.mkOption {
                  type = lib.types.str;
                  description = "Author name for Git commits";
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
                      ui.merge-editor = "code --wait";

                      signing = {
                        backend = "ssh";
                        backends.ssh.allowed-signers = "~/.ssh/allowedSigners";
                        behavior = "own";
                        # Use file path with .pub extension instead of inline key
                        # This fixes Bitwarden SSH agent compatibility with jj
                        key = "~/.ssh/signing-key.pub";
                      };

                      user = {
                        name = cfg.userName;
                        email = cfg.userEmail;
                      };
                    };
                  };
                };

                # Create SSH allowedSigners file for commit verification
                home.file.".ssh/allowedSigners".text = ''
                  ${builtins.concatStringsSep "\n" cfg.allowedSigningKeys}
                '';

                # Create SSH signing key file with .pub extension for jj compatibility
                # This is required for Bitwarden SSH agent to work properly with jj
                home.file.".ssh/signing-key.pub".text = cfg.signingKey;
              };
            }
          )
        ];
      };
    };
}
