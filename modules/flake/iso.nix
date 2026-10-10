{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      system,
      ...
    }:
    {
      # `nix build .#iso`: NixOS's minimal installer, reachable over SSH as
      # root@dots-installer.local, with `install-host` (docs/install.md). A
      # package rather than a host, so it stays out of the checks and the
      # installer's host menu.
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        iso =
          (inputs.nixpkgs.lib.nixosSystem {
            modules = [
              "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              (
                { pkgs, ... }:
                let
                  installHost = pkgs.writeShellApplication {
                    name = "install-host";
                    runtimeInputs = [ pkgs.tmux ];
                    text = ''
                      [[ $EUID -eq 0 ]] || exec sudo install-host "$@"
                      # In tmux, so a dropped SSH connection doesn't stop an
                      # install: running this again returns to it.
                      [[ -n ''${TMUX:-} ]] || exec tmux new-session -A -s install install-host "$@"
                      # The installer from Codeberg, so this ISO doesn't go stale.
                      exec nix run "git+https://codeberg.org/BW20/dots#install" -- "$@"
                    '';
                  };
                in
                {
                  nixpkgs.hostPlatform = system;
                  image.baseName = lib.mkForce "dots-installer";
                  networking.hostName = "dots-installer";
                  nix.settings.experimental-features = [
                    "nix-command"
                    "flakes"
                  ];

                  # Root by key only: the installer has no password.
                  users.users.root.openssh.authorizedKeys.keys = inputs.self.lib.authorizedKeys;
                  services.openssh.settings = {
                    PasswordAuthentication = false;
                    KbdInteractiveAuthentication = false;
                  };

                  # Found as dots-installer.local, without looking up its IP.
                  services.avahi = {
                    enable = true;
                    nssmdns4 = true;
                    publish = {
                      enable = true;
                      addresses = true;
                    };
                  };

                  # No services.pcscd: with the installer's polkit, NixOS's
                  # pcscd refuses clients (see secrets.nix). The installer
                  # starts a plain one itself.
                  environment.systemPackages = [
                    installHost
                    pkgs.nixos-facter
                  ];
                }
              )
            ];
          }).config.system.build.isoImage;
      };
    };
}
