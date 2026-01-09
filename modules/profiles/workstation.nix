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
        impermanence
        secrets

        # Apps
        ai-assistant
        browser
        editor
        messaging
        music-player
        notes
        password-manager
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
        session
        theming

        # Dev
        direnv
        git
        nix
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
      ];

      settings = {
        # Apps
        ai-assistant.enable = true;
        browser.enable = true;
        editor.enable = true;
        messaging.enable = true;
        music-player.enable = true;
        notes.enable = true;
        password-manager.enable = true;
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
        session.enable = true;
        theming.enable = true;

        # Dev
        direnv.enable = true;
        git.enable = true;
        nix.enable = true;
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

        # Wire idle to use lockscreen command
        idle.lockCommand = config.settings.lockscreen.command;

        # Wire session to use compositor config
        session.compositorName = config.settings.compositor.name;
        session.compositorSessionCommand = config.settings.compositor.sessionCommand;
      };
    };
}
