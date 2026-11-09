{
  lib,
  ...
}:
{
  # What the installer (scripts/install.sh) and its rehearsal VM
  # (scripts/install-vm.sh) read from the host they install, rather than
  # knowing themselves: the repository, where the host's files and secrets
  # are in it, and where things go on the new disk. The defaults are
  # generic; the base bundle sets this repository's values.
  flake.nixosModules.yubinstall =
    {
      config,
      ...
    }:
    let
      host = config.networking.hostName;
      str = lib.types.str;
    in
    {
      options.yubinstall = {
        checkout = {
          jj = lib.mkEnableOption "a colocated jj repository in the checkout, with the branch tracked";

          group = lib.mkOption {
            type = str;
            default = "root";
            description = "The group that owns the clone and may write to it.";
          };

          path = lib.mkOption {
            type = str;
            default = "/etc/nixos";
            description = "Where the installer copies its clone of the repository, on the new system: with a root wiped at boot, the persisted path.";
          };
        };

        hardwareReport = lib.mkOption {
          type = str;
          example = "hosts/${host}/facter.json";
          description = "The host's nixos-facter report, as a path in the repository: the installer checks its disks are there, and writes a new report there on new hardware.";
        };

        reportCommit = {
          email = lib.mkOption {
            type = str;
            default = "root@installer";
            description = "Author address of the commit with a new hardware report.";
          };

          name = lib.mkOption {
            type = str;
            default = "installer";
            description = "Author name of the commit with a new hardware report.";
          };
        };

        repository = {
          branch = lib.mkOption {
            type = str;
            default = "main";
            description = "The branch the installer pushes a new hardware report to.";
          };

          knownHosts = lib.mkOption {
            type = str;
            example = "codeberg.org ssh-ed25519 AAAA...";
            description = "The push host's key, as a known_hosts line: the live ISO has none.";
          };

          pushUrl = lib.mkOption {
            type = str;
            example = "ssh://git@codeberg.org/you/config.git";
            description = "Where the installer pushes a new hardware report, with the deploy key.";
          };

          remote = lib.mkOption {
            type = str;
            default = "origin";
            description = "The clone's name for the remote.";
          };

          url = lib.mkOption {
            type = str;
            example = "https://codeberg.org/you/config.git";
            description = "The repository the installer clones, installs from and copies to checkout.path.";
          };
        };

        secrets = {
          ageKey = lib.mkOption {
            type = str;
            default = "${host}_age_key";
            description = "The key in installerFile that holds the host's age secret key, which its secrets file is encrypted for.";
          };

          deployKey = lib.mkOption {
            type = str;
            default = "deploy_key";
            description = "The key in installerFile that holds the SSH key the installer pushes with.";
          };

          file = lib.mkOption {
            type = str;
            default = "secrets/${host}.yaml";
            description = "The host's sops file, as a path in the repository.";
          };

          installerFile = lib.mkOption {
            type = str;
            default = "secrets/installer.yaml";
            description = "The sops file with what only the installer needs, as a path in the repository: each host's age key and the deploy key.";
          };

          luksKeyFile = lib.mkOption {
            type = str;
            default = "/tmp/secret.key";
            description = "Where the installer writes the LUKS password on the live system, for disko's passwordFile.";
          };

          luksPassword = lib.mkOption {
            type = str;
            default = "luks_password";
            description = "The key in the host's secrets file that holds the LUKS password.";
          };
        };

        vm.restore = {
          endpoint = lib.mkOption {
            type = lib.types.nullOr str;
            default = null;
            example = "gateway.eu1.storjshare.io";
            description = "The one host, on port 443, the rehearsal VM may reach with --restore: the backup's.";
          };

          stopUnits = lib.mkOption {
            type = lib.types.listOf str;
            default = [ ];
            description = "Units the rehearsal VM is told to stop before a restore, so it can't back up over the host's real backup.";
          };
        };
      };
    };
}
