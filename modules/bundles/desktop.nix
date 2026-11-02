{
  inputs,
  ...
}:
{
  # The niri desktop. Its features lean on each other (app2unit, niri
  # settings, theming, noctalia), so they come as one. App and research
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
      nihil
      notifications
      polkit
      session
      theming
      weinig

      # Research
      research
    ];
  };
}
