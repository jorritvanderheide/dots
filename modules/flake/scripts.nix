{
  inputs,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      install-host = pkgs.writeShellApplication {
        name = "install-host";

        runtimeInputs = with pkgs; [
          age
          gnugrep
          gnused
          nixos-anywhere
          openssh
          sops
          sshpass
          ssh-to-age
        ];

        text = builtins.readFile (inputs.self + "/scripts/install-host.sh");
      };
    in
    {
      apps.install-host = {
        type = "app";
        program = "${install-host}/bin/install-host";
        meta.description = "Install a NixOS host from this flake (disko partitioning + nixos-install).";
      };

      packages.install-host = install-host;
    };
}
