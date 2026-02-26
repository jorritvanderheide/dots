{
  inputs,
  ...
}:
{
  flake.nixosModules.headless =
    { ... }:
    {
      imports = with inputs.self.nixosModules; [
        # Core
        boot
        disk
        facter
        home-manager
        preservation
        secrets

        # Dev
        direnv
        nix

        # Shell
        cli-tools
        prompt
        shell

        # Hardware
        firmware
        power

        # System
        locale
        networking
        ssh-server
        sudo
      ];

      settings = {
        # Dev
        direnv.enable = true;
        nix.enable = true;

        # Shell
        cli-tools.enable = true;
        prompt.enable = true;
        shell.enable = true;

        # Hardware
        firmware.enable = true;
        power.enable = true;

        # System
        locale.enable = true;
        networking.enable = true;
        ssh-server.enable = true;
        sudo.enable = true;
      };
    };
}
