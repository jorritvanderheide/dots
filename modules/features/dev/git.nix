{
  lib,
  ...
}:
{
  flake.nixosModules.git = {
    config = {
      home-manager.sharedModules = [
        (
          { config, pkgs, ... }:
          let
            cfg = config.my.git;

            # ssh-keygen, but signing with the FIDO2 key on whichever
            # YubiKey is plugged in, ~/.ssh/commit-signing-<serial>,
            # whatever key it's given: one key per YubiKey, as for sudo on
            # dapple (yubikey.nix). Made with no-touch-required: the key
            # being in is enough. Anything else, such as verifying, goes
            # through as it is.
            yubikeySigner = pkgs.writeShellApplication {
              name = "ssh-keygen-yubikey";

              runtimeInputs = [
                pkgs.openssh
                pkgs.yubikey-manager
              ];

              text = ''
                args=("$@")
                signing=false
                for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
                  if [[ "''${args[i]}" == -Y && "''${args[i + 1]}" == sign ]]; then
                    signing=true
                  fi
                done
                if [[ $signing == false ]]; then
                  exec ssh-keygen "$@"
                fi

                for serial in $(ykman list --serials); do
                  key="$HOME/.ssh/commit-signing-$serial"
                  if [[ -e "$key" ]]; then
                    for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
                      if [[ "''${args[i]}" == -f ]]; then
                        args[i + 1]="$key"
                      fi
                    done
                    exec ssh-keygen "''${args[@]}"
                  fi
                done

                echo "Plug in a YubiKey with a commit signing key (~/.ssh/commit-signing-<serial>) to sign." >&2
                exit 1
              '';
            };
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
              # What jj checks signatures against
              # (signing.backends.ssh.allowed-signers).
              home.file.".ssh/allowedSigners".text = ''
                ${builtins.concatStringsSep "\n" cfg.allowedSigningKeys}
              '';

              # The file jj signs with (programs.jujutsu's signing.key).
              home.file.".ssh/signing-key.pub".text = cfg.signingKey;

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

                  # Not in this flake, where jj signs on push with a
                  # YubiKey (below). A commit git signed with the
                  # Bitwarden key would be skipped by sign-on-push, and
                  # then not deployed.
                  includes = [
                    {
                      condition = "gitdir:/etc/nixos/";
                      contents.commit.gpgSign = false;
                    }
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
                    ui.merge-editor = ":builtin";

                    # In this flake, a signed commit on main is a deploy
                    # (comin.nix), so it's signed with a YubiKey, and only
                    # as it's pushed: a push takes the key in, with no
                    # touch. Nothing is signed before then, so rewriting
                    # needs no key.
                    "--scope" = [
                      {
                        "--when".repositories = [ "/etc/nixos" ];

                        git = {
                          sign-on-push = true;

                          # comin's go-git leaves the change-id header out
                          # when it checks a signature, so a commit with
                          # one never verifies, and never deploys.
                          write-change-id-header = false;
                        };

                        # What's on Codeberg's main is immutable, so jj
                        # won't rewrite it: comin refuses a force-pushed
                        # main. jj's default trunk() only knows a remote
                        # named origin, and finds none here.
                        revset-aliases."trunk()" = "main@codeberg";

                        signing = {
                          backends.ssh.program = lib.getExe yubikeySigner;
                          behavior = "drop";
                          key = "~/.ssh/commit-signing";
                        };
                      }
                    ];

                    # What a bare `jj sign` signs: the unsigned commits on this
                    # line, such as those made while signing was dropped. jj
                    # signs every revision it's given again, and its default,
                    # reachable(@, mutable()), takes in hundreds of signed ones.
                    revsets.sign = "::@ & mutable() & ~signed()";

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
