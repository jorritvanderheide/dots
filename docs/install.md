# Installing a host

## Install

Build the installer ISO and write it to a USB stick:

```sh
nix build .#iso
sudo dd if=result/iso/dots-installer.iso of=/dev/sdX bs=4M status=progress
```

Boot the target machine from it, with network (a cable, or `nmtui` on its
console) and a YubiKey plugged in: any of them, such as the host's own. Then,
from any computer with Bitwarden's SSH agent (it holds the key the ISO
accepts):

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

Or run `install-host <hostname>` on the ISO's own console.

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

A reinstalled host doesn't join: restoring its data (below) brings back its
Tailscale state, so it is on the tailnet as itself again, at its old address.
A new host joins once, since Headscale has to approve it:

```sh
sudo tailscale up --login-server=https://vpn.bw20.nl   # rocinante, or any other host
sudo tailscale up --login-server=http://127.0.0.1:8085 # dapple, which runs Headscale
```

It prints a link; the page behind it shows a `headscale nodes register`
command. Run that on dapple, with the user the device belongs to.

A reinstalled dapple needs both `headscale` and `tailscale` restored before
the tailnet works again: until then, reach it over the LAN
(`ssh nixos@192.168.1.162`). Dapple has to be at 100.64.0.1, where its
services and DNS records point. If it ever joins as a new device instead,
delete its old one first (`headscale nodes delete`): Headscale hands out
addresses in order, so dapple gets 100.64.0.1 again.

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

Restoring `tailscale` or `headscale` over the tailnet can cut your own SSH
session. The restore carries on regardless; reconnect and read
`/var/log/offsite-restore.log`. Over the LAN (`ssh nixos@192.168.1.162`) you
can watch it instead. A Headscale backup older than a device's registration
logs that device out of the tailnet.

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
existing host's. Boot the new machine from the ISO, and from a computer with
Bitwarden's SSH agent, get its hardware report:

```sh
ssh root@dots-installer.local nixos-facter > modules/hosts/<hostname>/facter.json
```

Commit both files and push them to Codeberg. Then install it like any other
host. The installer refuses a host without a `facter.json`. The report lists
the USB stick as a disk too; the installer skips USB disks when it picks the
one to wipe.

Without a second computer, as with a replacement laptop, run
`install-host --new-hardware <hostname>` on the ISO's console instead, once
the host's `configuration.nix` is on Codeberg. It gathers the report on the
machine itself and installs with it. After the first boot, commit and push
`modules/hosts/<hostname>/facter.json` from `/etc/nixos`.

## Losing a machine

Nothing needed to recover lives only on rocinante: the SSH keys are in
Bitwarden, the configuration is on Codeberg, the data on Storj, and the
YubiKeys are separate devices.

Every host decrypts with any of your YubiKeys. The passphrase identity works
for the installer, but a running host's services need a YubiKey: without
one, it boots but can't set its passwords or reach its backup.

- **rocinante.** On its replacement, with a YubiKey: boot the ISO
  (a stock NixOS ISO with the `nix run` command above works too), and run
  `install-host --new-hardware rocinante` on its console. After the first
  boot, push the new `facter.json` and run `sudo offsite-restore`. Only what
  rocinante's backup holds comes back: Zotero, and its place on the tailnet.
- **A YubiKey.** The other one works on every host meanwhile. Revoke the lost
  key and enroll a new one, as in [Secrets and keys](secrets.md).
- **Both machines.** Vaultwarden runs on dapple, so Bitwarden only has the
  offline copy on your phone. It holds the passphrase identity, the SSH keys
  and your Codeberg login. With a YubiKey left, install dapple with
  `install-host --new-hardware dapple` and `sudo offsite-restore`, which
  brings Vaultwarden back, and rocinante can follow.
  If no YubiKey is left, enroll a new one first, with the passphrase
  identity: on the ISO, `nix shell nixpkgs#sops nixpkgs#age-plugin-yubikey`
  has the tools.

That last case depends on your phone. An offline copy of the passphrase
identity and your Bitwarden recovery details, kept somewhere safe, removes
that dependency.
