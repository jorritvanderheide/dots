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
        ".ssh/jorrit@rootnet.nl.pub".text =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILstgbYXPbaEviS+6CaeU7FhT6qaTYZ9/edYKXtFyJAJ jorrit@rootnet.nl";
        ".ssh/kobo.pub".text =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVHAMFVZ/24DCKYsaKwP0svlTFHp4UFJd7YaqnFl4fh kobo";
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
          identityFile = "~/Git/PubHubs/ops/ssh/id_ilab";
          proxyJump = "lilo";
          user = "ilab";
        };

        "ilab2" = {
          hostname = "ilab2.ihub.ru.nl";
          identitiesOnly = true;
          identityFile = "~/Git/PubHubs/ops/ssh/id_ilab";
          proxyJump = "lilo";
          user = "ilab";
        };

        # Kobo Clara BW, its built-in OpenSSH (.kobo/ssh-enabled). A key of
        # its own: every Kobo ships the same host keys, so this one should
        # open nothing else. Only it is offered, as the agent's keys hit
        # MaxAuthTries before the password fallback.
        "kobo" = {
          hostname = "192.168.1.40";
          identitiesOnly = true;
          identityFile = "~/.ssh/kobo.pub";
          user = "root";
        };

        "lilo" = {
          hostname = "lilo.science.ru.nl";
          user = "jvanderheide";
        };

        "ph" = {
          hostname = "ph.ihub.ru.nl";
          identitiesOnly = true;
          identityFile = "~/Git/PubHubs/ops/ssh/id_ilab";
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

        # Rootnet whitelists only the home IP, so go out through dapple
        # (reachable over the tailnet from anywhere).
        "rootnet" = {
          hostname = "185.173.20.56";
          identitiesOnly = true;
          identityFile = "~/.ssh/jorrit@rootnet.nl.pub";
          proxyJump = "dapple";
          user = "innbw20nl_19";
        };
      };
    };

    # Rootnet's, from the first connection (2026-11-18): it gave no
    # fingerprint. meetinn's deploy workflow pins the same key.
    programs.ssh.knownHosts.rootnet = {
      hostNames = [ "185.173.20.56" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIV79HxjjWEj6tND6VwG+rukhBUhp+fwnU/clOvMNLrd";
    };
  };
}
