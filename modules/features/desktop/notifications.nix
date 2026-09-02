_: {
  flake.nixosModules.notifications =
    { pkgs, ... }:
    {
      config = {
        # libnotify provides `notify-send` for scripts and debugging,
        # regardless of which daemon (currently noctalia) receives it.
        environment.systemPackages = [ pkgs.libnotify ];
      };
    };
}
