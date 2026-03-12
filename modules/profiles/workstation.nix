{
  inputs,
  ...
}:
{
  flake.nixosModules.workstation =
    { config, ... }:
    {
      imports = with inputs.self.nixosModules; [
        # Core
        boot
        disk
        facter
        home-manager
        preservation
        secrets

        # Apps
        browser
        cad
        editor
        email
        gaming
        media-player
        messaging
        music-player
        notes
        password-manager
        social
        terminal

        # Desktop
        app-launch
        clipboard
        compositor
        desktop-shell
        idle
        keybinds
        keyboard-remap
        launcher
        lockscreen
        polkit
        session
        theming

        # Dev
        coding-agent
        direnv
        git
        nix
        # pubhubs
        virtualization

        # Hardware
        bluetooth
        firmware
        power
        sound

        # Shell
        cli-tools
        prompt
        shell

        # System
        locale
        networking
        ssh
        sudo
        vpn
      ];

      settings = {
        # Apps
        browser.enable = true;
        # cad.enable = true; # Disabled: freecad fails to build
        editor.enable = true;
        email.enable = true;
        gaming.enable = true;
        media-player.enable = true;
        messaging.enable = true;
        music-player.enable = true;
        notes.enable = true;
        password-manager.enable = true;
        social.enable = true;
        terminal.enable = true;

        # Desktop
        app-launch.enable = true;
        clipboard.enable = true;
        compositor.enable = true;
        desktop-shell.enable = true;
        idle.enable = true;
        keybinds.enable = true;
        keyboard-remap.enable = true;
        launcher.enable = true;
        lockscreen.enable = true;
        polkit.enable = true;
        theming.enable = true;

        session = {
          enable = true;
          # Wire session to use compositor config
          compositorName = config.settings.compositor.name;
          compositorSessionCommand = config.settings.compositor.sessionCommand;
        };

        # Dev
        coding-agent.enable = true;
        direnv.enable = true;
        git.enable = true;
        nix.enable = true;
        # pubhubs.enable = false;
        virtualization.enable = true;

        # Hardware
        bluetooth.enable = true;
        firmware.enable = true;
        power.enable = true;
        sound.enable = true;

        # Shell
        cli-tools.enable = true;
        prompt.enable = true;
        shell.enable = true;

        # System
        locale.enable = true;
        networking.enable = true;
        ssh.enable = true;
        sudo.enable = true;
        vpn.enable = true;

        # Wire idle to use lockscreen command
        idle.lockCommand = config.settings.lockscreen.command;
      };
    };
}
