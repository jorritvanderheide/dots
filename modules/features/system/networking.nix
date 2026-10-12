{
  flake.nixosModules.networking =
    { pkgs, ... }:
    {
      config = {
        # nm-connection-editor, for viewing/editing NetworkManager connection
        # profiles (e.g. ad-hoc Wi-Fi not declared in wifi.nix). The package
        # also autostarts nm-applet in a desktop session; notifications.nix
        # turns off its connect notifications.
        environment.systemPackages = [ pkgs.networkmanagerapplet ];

        networking = {
          # NetworkManager runs its own DHCP client per-interface; without this
          # NixOS's global dhcpcd.service also runs and races it on the same
          # interface, producing two conflicting default routes/leases (seen
          # on iotroam: two "default via" routes with different src IPs).
          # (networking.useDHCP is not the relevant knob here: enabling
          # NetworkManager already forces that to false internally. dhcpcd.enable
          # is a separate option that defaults to true regardless.)
          dhcpcd.enable = false;

          networkmanager.enable = true;
        };
      };
    };
}
