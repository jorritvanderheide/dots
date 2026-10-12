{
  inputs,
  ...
}:
{
  # The niri desktop. Its features lean on each other (app2unit, niri
  # settings, stylix, noctalia), so they come as one. App and research
  # features build on it, and research holds the settings those read.
  flake.nixosModules.desktop = {
    imports = with inputs.self.nixosModules; [
      # Desktop
      app-launch
      compositor
      desktop-shell
      files
      keybinds
      keyboard-remap
      notifications
      polkit
      session
      theming

      # Research
      research
    ];
  };
}
