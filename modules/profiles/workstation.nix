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
        bitwarden
        browser
        editor
        messaging
        notes
        terminal

        # Desktop
        app-launch
        clipboard
        compositor
        idle
        keybinds
        keyboard-remap
        launcher
        lockscreen
        session
        theming

        # Dev
        git
        nix

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

      features = {
        # Apps
        ai-assistant.enable = true;
        bitwarden.enable = true;
        browser.enable = true;
        editor.enable = true;
        messaging.enable = true;
        notes.enable = true;
        terminal.enable = true;

        # Desktop
        app-launch.enable = true;
        clipboard.enable = true;
        compositor.enable = true;
        idle.enable = true;
        keybinds.enable = true;
        keyboard-remap.enable = true;
        launcher.enable = true;
        lockscreen.enable = true;
        session.enable = true;
        theming.enable = true;

        # Dev
        git.enable = true;
        nix.enable = true;

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
        idle.lockCommand = config.features.lockscreen.command;

        # Wire session to use compositor config
        session.compositorName = config.features.compositor.name;
        session.compositorSessionCommand = config.features.compositor.sessionCommand;
      };

      # Disable GNOME gcr-ssh-agent (conflicts with SSH agent)
      services.gnome.gcr-ssh-agent.enable = false;
    };
}
