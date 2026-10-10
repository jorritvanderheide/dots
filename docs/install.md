# Installing a host

## Install

Boot a NixOS live ISO on the target machine, with network and the YubiKey
plugged in. Then, with no local checkout needed:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run "git+https://codeberg.org/BW20/dots#install" -- <hostname>
```

This partitions and formats the disk (disko, after a `yes` confirmation,
since it wipes the disk) and runs `nixos-install` without asking for a root
password. The first boot needs the LUKS password typed by hand once.

TPM2 auto-unlock is *not* enrolled automatically. Once logged in, run
`nix run .#enroll-tpm` on the host itself to bind a keyslot. The same
command re-enrolls later, for example after a firmware or TPM reset.

## Why the accounts start locked

Neither `root` nor `jorrit` can reliably get their sops-encrypted password
inside `nixos-install`'s bare chroot: there is no systemd there, so pcscd's
socket activation for the YubiKey doesn't apply. The installer leaves both
accounts locked.

The same limitation applies on *every* boot, not just the install.
`boot.initrd.systemd.enable`, which the ZFS rollback needs, makes each boot's
activation run chrooted into `/sysroot` from the initrd, before the real
systemd and pcscd exist there. So `set-password-root`, `set-password-jorrit`
and `tpm2-luks-enroll` don't rely on sops-nix's activation-time install. Each
decrypts its own secret (`sops -d --extract`) as a real service under the
booted system's systemd, after `pcscd.service`. Log in as `jorrit` (or
`root`) once that has had a moment to run after boot.

## Expected errors

For the same reason, `nixos-install` prints `Activation script snippet
'setupSecrets' failed (1)` and "0 successful groups required, got 0", and
finishes with "finalized with 1 error". That is expected, not a failed
install. Only `luks_password` needs to decrypt during the install, and
`install.sh` extracts that one separately, with pcscd started by hand,
before `nixos-install` runs.

If disko's `zpool create` fails with "The ZFS modules cannot be
auto-loaded", run the same `install` command again. The first attempt loads
the module as a side effect, so the retry succeeds.

## A new host

A host with no `modules/hosts/<hostname>/facter.json` committed yet needs a
local, writable checkout instead. The script writes the hardware report back
to the repository, which a read-only fetched flake can't do:

```sh
git clone https://codeberg.org/BW20/dots && cd dots
sudo INSTALL_HOST_FLAKE_DIR="$PWD" nix run .#install -- <hostname>
```

Then commit and push the new `facter.json` before reinstalling that host.
