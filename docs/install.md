# Installing a host

## Install

Boot a NixOS live ISO on the target machine, with network and a YubiKey
plugged in: any of them, such as the host's own. Then, with no local
checkout needed:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run "git+https://codeberg.org/BW20/dots#install" -- <hostname>
```

Without a host name, it asks which one to install. The installer:

1. Checks that the host's disk is there, by its model and serial. If it
   isn't, the hardware report is from another machine, and it stops.
2. Decrypts the LUKS password with the YubiKey that is plugged in.
3. Shows the disk it is about to wipe, with its size, and waits for a `yes`.
4. Partitions and formats it with disko, and runs `nixos-install`.
5. Clones this repository to `/etc/nixos`, with Codeberg as the `codeberg`
   remote (pushing over SSH), ready for `jj`.

Then reboot, with the YubiKey still in, and type the LUKS password. That is
the only time: the first boot enrolls the TPM, and later boots unlock by
themselves. After a firmware or TPM reset, re-enroll with
`sudo nix run /etc/nixos#enroll-tpm`.

## Why the accounts start locked

Neither `root` nor `jorrit` can reliably get their sops-encrypted password
inside `nixos-install`'s bare chroot: there is no systemd there, so pcscd's
socket activation for the YubiKey doesn't apply. The installer leaves both
accounts locked.

The same limitation applies on *every* boot, not just the install.
`boot.initrd.systemd.enable`, which the ZFS rollback needs, makes each boot's
activation run chrooted into `/sysroot` from the initrd, before the real
systemd and pcscd exist there. So `set-password-root`, `set-password-jorrit`
and `tpm2-luks-enroll` decrypt their own secret (`sops -d --extract`) as a
real service under the booted system's systemd, after `pcscd.service`. Log
in as `jorrit` (or `root`) once that has had a moment to run after boot.

## Joining the tailnet

Joining is one manual step, since it needs an approval in Headscale:

```sh
sudo tailscale up --login-server=https://vpn.bw20.nl   # rocinante, or any other host
sudo tailscale up --login-server=http://127.0.0.1:8085 # dapple, which runs Headscale
```

It prints a link; the page behind it shows a `headscale nodes register`
command. Run that on dapple, with the user the device belongs to.

A reinstalled dapple starts with an empty Headscale. Restore it first (see
below), and the other devices keep working; only dapple itself joins again.

## Restoring data

A reinstalled host starts without its services' data. Bring it back from the
offsite backup on Storj, once the host is up:

```sh
sudo offsite-restore              # everything
sudo offsite-restore immich       # or only what's named; --help lists them
```

It downloads first, so a failed download changes nothing. Then it stops the
services, swaps their data in, puts back what is backed up as a dump or a
copy (Immich's database, Vaultwarden), and starts them again. What it replaced is kept
in `/persist/.offsite-restore-old-<time>` until you delete it. The same
command repairs a single service on a running host.

To check a backup without changing anything,
`sudo offsite-restore --target /tmp/restore-test <entry>` only downloads.

## A new host

A host with no `modules/hosts/<hostname>/facter.json` committed yet needs a
local, writable checkout instead, with its `configuration.nix` in it. The
script writes the hardware report back to the repository, which a read-only
fetched flake can't do:

```sh
git clone https://codeberg.org/BW20/dots && cd dots
sudo INSTALL_HOST_FLAKE_DIR="$PWD" nix run .#install -- <hostname>
```

The checkout is copied to `/etc/nixos` as it is, so commit and push the new
`facter.json` from there once the host is up.
