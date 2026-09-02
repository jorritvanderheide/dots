{
  lib,
  ...
}:
{
  flake.nixosModules.git = {
    config = {
      home-manager.sharedModules = [
        (
          { config, ... }:
          let
            cfg = config.my.git;
          in
          {
            options.my.git = {
              allowedSigningKeys = lib.mkOption {
                description = "Allowed SSH public keys for commit signature verification";
                type = lib.types.listOf lib.types.str;
              };

              signingKey = lib.mkOption {
                description = "SSH public key used to sign commits";
                type = lib.types.str;
              };

              userEmail = lib.mkOption {
                description = "Email address for Git commits";
                type = lib.types.str;
              };

              userName = lib.mkOption {
                description = "Author name for Git commits";
                type = lib.types.str;
              };
            };

            config = {
              # Create SSH signing key file with .pub extension for jj compatibility
              # This is required for Bitwarden SSH agent to work properly with jj
              home.file.".ssh/signing-key.pub".text = cfg.signingKey;

              # Create SSH allowedSigners file for commit verification
              home.file.".ssh/allowedSigners".text = ''
                ${builtins.concatStringsSep "\n" cfg.allowedSigningKeys}
              '';

              programs = {
                gh.enable = true;

                git = {
                  enable = true;

                  ignores = [
                    ".claude/"
                    ".direnv/"
                    ".envrc"
                    "CLAUDE.md"
                    "result/"
                  ];

                  settings = {
                    gpg.ssh.allowedSignersFile = "~/.ssh/allowedSigners";
                    init.defaultBranch = "main";
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
                    ui.merge-editor = ":builtin";

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
            };
          }
        )
      ];

      my.preservation.homeDirectories = [
        # gh auth login stores its token here (hosts.yml); without this it's
        # lost on reboot and every session needs `gh auth login` again.
        ".config/gh"
        "Git"
      ];
    };
  };
}
