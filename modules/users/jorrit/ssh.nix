# The hosts jorrit reaches over SSH, and the keys for them. The user itself
# is in configuration.nix.
{
  flake.nixosModules.jorrit = {
    home-manager.users.jorrit = {
      # Public halves only: the private keys live in the Bitwarden SSH
      # agent (password-manager.nix), and IdentitiesOnly + IdentityFile
      # only need the public half to pick one from it. `ssh-add -L`
      # re-derives them.
      home.file = {
        ".ssh/git@codeberg.org.pub".text =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDBw6g7ruZDtFHuzlzPWLKmN8yeQTrrx88eC92ECMDC git@codeberg.org";
        ".ssh/git@github.com.pub".text =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW60Nybd6kk9zSurQJmpUODQDw0p41Pc/G/kt/CQ/Qy git@github.com";
        ".ssh/git@gitlab.science.ru.nl.pub".text =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK7PikkKt9lBCZDYpCZm8fFPx+oZ1EQWPhlzREkboFA git@gitlab.science.ru.nl";
      };

      programs.ssh.settings = {
        "codeberg.org" = {
          identitiesOnly = true;
          identityFile = "~/.ssh/git@codeberg.org.pub";
          user = "git";
        };

        "github.com" = {
          identitiesOnly = true;
          identityFile = "~/.ssh/git@github.com.pub";
          user = "git";
        };

        "gitlab.science.ru.nl" = {
          identitiesOnly = true;
          identityFile = "~/.ssh/git@gitlab.science.ru.nl.pub";
          user = "git";
        };

        "ilab1" = {
          hostname = "ilab1.ihub.ru.nl";
          identitiesOnly = true;
          identityFile = "~/Git/ops/ssh/id_ilab";
          proxyJump = "lilo";
          user = "ilab";
        };

        "ilab2" = {
          hostname = "ilab2.ihub.ru.nl";
          identitiesOnly = true;
          identityFile = "~/Git/ops/ssh/id_ilab";
          proxyJump = "lilo";
          user = "ilab";
        };

        "lilo" = {
          hostname = "lilo.science.ru.nl";
          user = "jvanderheide";
        };

        "ph" = {
          hostname = "ph.ihub.ru.nl";
          identitiesOnly = true;
          identityFile = "~/Git/ops/ssh/id_ilab";
          proxyJump = "lilo";
          user = "ilab";
        };

        "radboud-hub" = {
          hostname = "pubhubs.ru.nl";
          identitiesOnly = true;
          identityFile = "~/.ssh/git@gitlab.science.ru.nl.pub";
          proxyJump = "lilo";
          user = "jvanderheide";
        };
      };
    };
  };
}
