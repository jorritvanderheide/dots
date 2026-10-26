_: {
  # Facts and keys more than one feature or host needs, in inputs.self.lib
  # with the helpers of lib.nix.
  flake.lib = {
    # Keys that may SSH into the hosts (the nixos user) and the installer ISO.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante"
    ];

    # Whose signed commits on Codeberg's main the hosts deploy (comin.nix),
    # as lines of an allowed signers file: a FIDO2 key on each YubiKey,
    # which jj signs this flake's commits with on push (git.nix).
    commitSigners = [
      "jorrit+git@bw20.nl sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHULULWxUcX3Lg1BsXJjB+istuEq1Y6xuWktI3QZXkdqAAAAEnNzaDpjb21taXQtc2lnbmluZw== commit signing, YubiKey 29635974"
      "jorrit+git@bw20.nl sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICm1/QH7eIsiAtMpeWNdvRcMUHpIJ/862FexkZ8Ks4Y0AAAAEnNzaDpjb21taXQtc2lnbmluZw== commit signing, YubiKey 38555351"
    ];

    # Nix signing keys whose store paths a host you deploy to accepts
    # (ssh-server.nix): rocinante's, whose secret half is in its
    # secret-key-files.
    deployKeys = [ "rocinante-1:vJ6haHwJG0MjuqKeBc/HimPc4OvrIvqf/FUqK9HxKsU=" ];

    # Facts more than one host needs.
    site = {
      acmeEmail = "jorrit+acme@bw20.nl";
      domain = "bw20.nl";
      lan.subnet = "192.168.1.0/24";
      vpnDomain = "vpn.bw20.nl";

      # Every host, by name: what the others need to reach it. Headscale
      # hands out tailnet addresses in order, and dapple joined first
      # (docs/install.md).
      hosts = {
        rocinante.tailnetIp = "100.64.0.2";

        dapple = {
          lanIp = "192.168.1.162";
          tailnetIp = "100.64.0.1";

          # Its SSH host key, which the ssh feature pins. The private half
          # is ssh_host_key in secrets/dapple.yaml (ssh-server.nix).
          hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUeoBcfcYFUgUVYghcX5iksqBYrwIB/fgB/6QTucQ0L";
        };
      };

      # Gatus, on dapple (gatus.nix): what every host reports its disks to.
      statusPage = "https://status.bw20.nl";

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

      # The person's username, on every host and in the services that keep
      # an account for them (ntfy, File Browser).
      user = "jorrit";
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
