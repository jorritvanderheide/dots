{
  inputs,
  ...
}:
{
  # The niri desktop. Its features lean on each other (niri
  # settings, theming, weinig), so they come as one. App and research
  # features build on it, and research holds the settings those read.
  flake.nixosModules.desktop = {
    imports = with inputs.self.nixosModules; [
      # Desktop
      compositor
      files
      keybinds
      keyboard-remap
      notifications
      session
      theming

      # Research
      research
    ];
  };
}
