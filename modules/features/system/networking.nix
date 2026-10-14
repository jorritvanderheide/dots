{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.networking = _: {
    options.my.lan = {
      interface = lib.mkOption {
        type = lib.types.str;
        description = "The host's interface on the home LAN, where the router's port forwards arrive too. Read by the services that open a port to the LAN.";
      };

      subnet = lib.mkOption {
        type = lib.types.str;
        default = inputs.self.lib.site.lan.subnet;
        defaultText = lib.literalExpression "inputs.self.lib.site.lan.subnet";
        description = "The home LAN's subnet.";
      };
    };

    config = {
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
