_: {
  # Facts and keys more than one feature or host needs, in inputs.self.lib
  # with the functions of lib.nix.
  flake.lib = {
    # Keys that may SSH into the hosts (the nixos user) and the installer ISO.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante"
    ];

    # Facts more than one host needs.
    site = {
      domain = "bw20.nl";
      lan.subnet = "192.168.1.0/24";

      # Gatus, on dapple (gatus.nix): what every host reports its disks to.
      statusPage = "https://status.bw20.nl";

      vpnDomain = "vpn.bw20.nl";

      dapple = {
        lanIp = "192.168.1.162";

        # Headscale hands out addresses in order, and dapple joined first
        # (docs/install.md).
        tailnetIp = "100.64.0.1";
      };

      # rocinante's documents and dapple's copy (file-sync.nix,
      # syncthing.nix). A device's ID is the hash of its key, which is in
      # its persisted state.
      syncthing = {
        port = 22000;

        devices = {
          dapple = "T5ZF3AC-HREZOUC-4MKGOWC-3PEWHOZ-WT75JQF-UTKPCZ6-2TN4TKZ-OWUXZQE";
          rocinante = "RMKDHFZ-P6LQ5NT-OXRSEGM-5AKMNDZ-LQNUVY2-KKWQZV3-6Q2YBM5-LZALDQQ";
        };
      };
    };

    # Keys that may run sudo on dapple (ssh-server.nix), instead of the
    # password: a FIDO2 key on each YubiKey, which signs only with a touch.
    # rocinante forwards an agent with just these (yubikey.nix).
    sudoKeys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMYYBraKSjuNIGKNBS+PZbBgt62xtBdI8sM7db+48RVGAAAAD3NzaDpkYXBwbGUtc3Vkbw== sudo on dapple, YubiKey 29635974"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHm7J1sZHLzDlApmO/AvVs6l8Dlj0hiCSoPsNzOirNKgAAAAD3NzaDpkYXBwbGUtc3Vkbw== sudo on dapple, YubiKey 38555351"
    ];

  };
}
