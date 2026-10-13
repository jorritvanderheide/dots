# Installing a host

## Install

Build the installer ISO and write it to a USB stick:

```sh
nix build .#iso
sudo dd if=result/iso/dots-installer.iso of=/dev/sdX bs=4M status=progress
```

On a [Ventoy](https://www.ventoy.net) stick, copy
`result/iso/dots-installer.iso` onto it instead, and pick it from Ventoy's
menu at boot.

Put the machine's firmware in setup mode first (see
[Secure boot](#secure-boot)): the ISO isn't signed, and a reinstalled host
makes new keys. Boot the target machine from it, with network (a cable, or
`nmtui` on its console) and a YubiKey plugged in that opens the host's
secrets ([Secrets and keys](secrets.md)): either of the two, for either host
(dapple's with its PIN). Then,
from any computer with Bitwarden's SSH agent (it holds the key the ISO
accepts):

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

Or run `install-host <hostname>` on the ISO's own console.

Without a host name, it asks which one to install. It runs in tmux, so if
the SSH connection drops, the same command takes you back to it.
`install-host` runs the installer from Codeberg, so push before installing;
the ISO itself only needs rebuilding when `install-host` or the SSH keys it
accepts change (`modules/flake/iso.nix`, `modules/flake/lib.nix`), or for a
newer NixOS.

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
3. Makes the host a new age key of its own, and re-encrypts its secrets
   file for it, with the same YubiKey
   ([A new host key](secrets.md#a-new-host-key)).
4. Shows the disk it is about to wipe, with its size, and waits for a `yes`.
5. Partitions and formats it with disko, runs `nixos-install`, and puts the
   age key in `/persist`.
6. Clones this repository to `/etc/nixos`, with Codeberg as the `codeberg`
   remote (pushing over SSH), ready for `jj`.

Then reboot and type the LUKS password. Until secure boot is on, every boot
asks for it: the first boot makes the secure boot keys, the next one
enrolls them ([Secure boot](#secure-boot)), and the first boot with secure
boot on binds the TPM, after which boots unlock by themselves.

The host decrypts its secrets with its own age key from the first boot, so
it needs no YubiKey. The new key's `.sops.yaml` and re-encrypted secrets
file are uncommitted changes in `/etc/nixos`: commit and push them after
the first boot, or the next deploy from elsewhere puts the old file back.

## Secure boot

Both hosts boot with secure boot, with keys of their own
([lanzaboote](https://github.com/nix-community/lanzaboote)), and the TPM
only unlocks the disk for a boot that has it on with those keys (PCR 7). The
firmware takes the keys once, in setup mode:

1. Switch to a configuration with lanzaboote, or install one. Its first boot
   (or the switch) makes the keys, in `/persist/system/var/lib/sbctl`, and
   puts them on the ESP for enrolling.
2. In the firmware's setup, put secure boot in setup mode (usually "reset to
   setup mode" or "clear secure boot keys").
3. Reboot. systemd-boot enrolls the keys by itself, with Microsoft's for the
   hardware's option ROMs, and reboots.
4. In the firmware's setup, turn secure boot on if it isn't, and set an
   administrator password, so the keys can't be cleared or replaced without
   it.
5. Boot. `bootctl status` shows `Secure Boot: enabled (user)`. On a fresh
   install, that boot binds the TPM by itself. On a host that had a TPM
   slot already, rebind it: `sudo enroll-tpm`.
6. Check that the TPM slot is bound to PCR 7 (`luksDump` doesn't show
   PCRs), and that a reboot unlocks by itself:
   ```sh
   sudo sh -c 'for i in 0 1 2; do cryptsetup token export --token-id $i /dev/disk/by-partlabel/disk-main-luks; echo; done 2>/dev/null' | grep -o '"tpm2-pcrs":\[[^]]*\]'
   ```
   It should print `"tpm2-pcrs":[7]`.

A firmware update (fwupd, on rocinante) or a new revocation list can change
PCR 7. The next boot asks for the LUKS password then; after it, rebind with
`sudo enroll-tpm`. That's also the fix after a TPM reset.

## Why the accounts start locked

Neither `root` nor `jorrit` can get their sops-encrypted password inside
`nixos-install`'s bare chroot: a fresh install has no age key of its own
yet, and there is no systemd there, so pcscd's socket activation for the
YubiKey doesn't apply. The installer leaves both accounts locked.

The passwords are set by services on every boot anyway, not at activation:
`boot.initrd.systemd.enable`, which the ZFS rollback needs, makes each
boot's activation run chrooted into `/sysroot` from the initrd, before the
real systemd and pcscd exist there. So `set-password-root`,
`set-password-jorrit` and `tpm2-luks-enroll` decrypt their own secret as a
real service under the booted system's systemd, with the host's own age key,
which the installer put in place. Log in as
`jorrit` (or `root`) once that has had a moment to run after boot.

## Joining the tailnet

A reinstalled host doesn't join: restoring its data (below) brings back its
Tailscale state, so it is on the tailnet as itself again, at its old address.
A new host joins once, since Headscale has to approve it:

```sh
sudo tailscale up --login-server=https://vpn.bw20.nl   # rocinante, or any other host
sudo tailscale up --login-server=http://127.0.0.1:8085 # dapple, which runs Headscale
```

It prints a link; the page behind it shows a `headscale nodes register`
command. Run that on dapple, with the user the device belongs to. dapple
itself is then made a server rather than someone's device, which the
access policy (`modules/features/services/headscale/headscale-policy.hujson`)
counts on:

```sh
sudo headscale nodes list                       # dapple's ID
sudo headscale nodes tag -i <id> -t tag:server
```

A new device gets the services on dapple. If it also needs SSH or the LAN,
add its address to the policy's `hosts` and grants.

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

Each host has its own secrets file ([Secrets and keys](secrets.md)), which
its own age key opens, and either YubiKey (dapple's with its PIN). The
passphrase identity opens both, for the installer. The installer gives a
reinstalled host a new age key of its own
([A new host key](secrets.md#a-new-host-key)), so its services need no
YubiKey.

- **rocinante.** On its replacement, with a YubiKey: boot the ISO
  (a stock NixOS ISO with the `nix run` command above works too), and run
  `install-host --new-hardware rocinante` on its console. After the first
  boot, push the new `facter.json` and run `sudo offsite-restore`. Only what
  rocinante's backup holds comes back: Zotero, and its place on the tailnet.
- **A YubiKey.** Revoke the lost key and enroll a new one, as in
  [Secrets and keys](secrets.md), with the passphrase identity or the other
  key. The new key gets both identities, a no-PIN and a PIN one, like the
  other.
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
