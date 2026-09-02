{
  flake.nixosModules.polkit = _: {
    config = {
      # Core polkit framework/daemon -- noctalia's own authentication
      # agent (see my.desktop-shell) answers the actual requests.
      security.polkit.enable = true;
    };
  };
}
