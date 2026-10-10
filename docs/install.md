# Installing a host

## Install

Build the installer ISO and write it to a USB stick:

```sh
nix build .#iso
sudo dd if=result/iso/dots-installer.iso of=/dev/sdX bs=4M status=progress
```

Boot the target machine from it, with network (a cable, or `nmtui` on its
console) and a YubiKey plugged in: any of them, such as the host's own. Then,
from rocinante:

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

Without a host name, it asks which one to install. It runs in tmux, so if
the SSH connection drops, the same command takes you back to it.
`install-host` runs the installer from Codeberg, so push before installing;
the ISO itself only needs rebuilding for a newer NixOS.

A machine without a screen and keyboard has to boot from the stick by itself.
If its firmware doesn't, its boot menu needs them once.

Any other NixOS live ISO works too, from its own console:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run "git+https://codeberg.org/BW20/dots#install" -- <hostname>
```

The installer:

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

On a running dapple, restore `headscale` over the LAN
(`ssh nixos@192.168.1.162`), not over the tailnet: while Headscale is
stopped, or if the backup is older than a device's registration, the tailnet
may not carry your SSH session.

To undo a restore, put the replaced data back. For example, for Headscale:

```fish
sudo systemctl stop headscale
set old (ls -d /persist/.offsite-restore-old-* | tail -n 1)
sudo find /persist/system/var/lib/headscale -mindepth 1 -maxdepth 1 -exec rm -rf {} +
sudo find "$old"/var/lib/headscale -mindepth 1 -maxdepth 1 -exec mv -t /persist/system/var/lib/headscale {} +
sudo systemctl start headscale
```

## A new host

Write `modules/hosts/<hostname>/configuration.nix` first, starting from an
existing host's. Boot the new machine from the ISO, and from rocinante, get
its hardware report:

```sh
ssh root@dots-installer.local nixos-facter > modules/hosts/<hostname>/facter.json
```

Commit both files and push them to Codeberg. Then install it like any other
host. The installer refuses a host without a `facter.json`. The report lists
the USB stick as a disk too; the installer skips USB disks when it picks the
one to wipe.
