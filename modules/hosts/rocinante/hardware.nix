{
  flake.nixosModules.rocinante-hardware =
    {
      config,
      pkgs,
      ...
    }:
    {
      # What a Framework Laptop 13 (13th gen Intel) needs beyond what
      # nixos-facter detects, taken from nixos-hardware's
      # framework-13th-gen-intel module.

      boot = {
        # Not used for the Framework's EC, and logs an error at boot.
        blacklistedKernelModules = [ "cros-usbpd-charger" ];

        # The community EC driver. Weinig reads the camera and microphone
        # switches from the framework_privacy file it adds.
        extraModulePackages = [ config.boot.kernelPackages.framework-laptop-kmod ];

        kernelModules = [
          "cros_ec"
          "cros_ec_lpcs"
        ];

        # Lower idle power use of the NVMe drive.
        kernelParams = [ "nvme.noacpi=1" ];
      };

      # Its udev rule makes the backlight writable for the video group,
      # which wluma (auto-brightness.nix) writes through.
      hardware.acpilight.enable = true;

      # VA-API video decoding on the Iris Xe GPU.
      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
    };
}
