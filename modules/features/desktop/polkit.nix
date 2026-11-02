{
  flake.nixosModules.polkit = _: {
    config = {
      # Core polkit framework/daemon; Weinig's authentication agent
      # (weinig.nix) answers the actual requests.
      security.polkit.enable = true;
    };
  };
}
