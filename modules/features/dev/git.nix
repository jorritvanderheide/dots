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
              # The file jj signs with (programs.jujutsu's signing.key).
              home.file.".ssh/signing-key.pub".text = cfg.signingKey;

              # What jj checks signatures against
              # (signing.backends.ssh.allowed-signers).
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
                    "TODO.md"
                  ];

                  settings = {
                    gpg.ssh.allowedSignersFile = "~/.ssh/allowedSigners";
                    init.defaultBranch = "main";
                    safe.directory = [ "/etc/nixos" ];

                    user = {
                      email = cfg.userEmail;
                      name = cfg.userName;
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
                    # What a bare `jj sign` signs: the unsigned commits on this
                    # line, such as those made while signing was dropped. jj
                    # signs every revision it's given again, and its default,
                    # reachable(@, mutable()), takes in hundreds of signed ones.
                    revsets.sign = "::@ & mutable() & ~signed()";

                    ui.merge-editor = ":builtin";

                    signing = {
                      backend = "ssh";
                      backends.ssh.allowed-signers = "~/.ssh/allowedSigners";
                      behavior = "own";

                      # A path, not the key inline: jj only signs through
                      # Bitwarden's agent given the .pub file.
                      key = "~/.ssh/signing-key.pub";
                    };

                    user = {
                      email = cfg.userEmail;
                      name = cfg.userName;
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
