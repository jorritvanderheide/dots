_: {
  flake.nixosModules.yubikey =
    { pkgs, ... }:
    {
      config = {
        environment.systemPackages = [
          # GUI: manage OATH/FIDO2/PIV/OTP applets, view codes.
          pkgs.yubioath-flutter
          # CLI fallback for anything the GUI doesn't cover.
          pkgs.yubikey-manager
        ];

        services.udev.packages = [ pkgs.yubikey-personalization ];
      };
    };
}
