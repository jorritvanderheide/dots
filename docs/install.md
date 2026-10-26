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
makes new keys. Boot the target machine from it, with network (a cable,
or `nmtui` on its console) and either YubiKey plugged in
([Secrets and keys](secrets.md)), dapple's with its PIN. Then, from any
computer with Bitwarden's SSH agent (it holds the key the ISO accepts):

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

Or run `install-host <hostname>` on the ISO's own console.

Without a host name, it asks which one to install. It runs in tmux, so if
the SSH connection drops, the same command takes you back to it.
`install-host` runs the installer from Codeberg, so push before installing;
the ISO itself only needs rebuilding when `install-host` or the SSH keys it
accepts change (`modules/flake/iso.nix`, `modules/flake/site.nix`), or for a
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
4. Shows the disk it is about to wipe, with its size, and any it keeps,
   and waits for a `yes`. It keeps dapple's media disk, which has no
   offsite copy: its LUKS is opened and its pool imported, as they are.
5. Partitions and formats the main disk with disko, puts the age key in
   `/persist`, and runs `nixos-install`, whose activation decrypts the
   secrets with it: the accounts have their passwords from the first boot.
6. Clones this repository to `/etc/nixos`, with Codeberg as the `codeberg`
   remote (pushing over SSH), and exports the pools, so the first boot
   imports them. rocinante works in the clone with `jj`; dapple has no git,
   and its clone only carries the new key's files back (below).

Then reboot and type the LUKS password. Until secure boot is on, every boot
asks for it: the first boot makes the secure boot keys, the next one
enrolls them ([Secure boot](#secure-boot)), and the first boot with secure
boot on binds the TPM, after which boots unlock by themselves.

The host decrypts its secrets with its own age key from the first boot, so
it needs no YubiKey. The new key's `secrets/.sops.yaml` and re-encrypted
secrets file are uncommitted changes in its `/etc/nixos`: commit and push
them after the first boot, or the next deploy from elsewhere puts the old
file back. rocinante commits them where they are; for dapple, copy them
into rocinante's clone and commit there. Its SSH host key is one of its
secrets, so `ssh dapple` trusts it from the first boot:

```sh
ssh dapple cat /etc/nixos/secrets/.sops.yaml > secrets/.sops.yaml.new && mv secrets/.sops.yaml.new secrets/.sops.yaml
ssh dapple cat /etc/nixos/secrets/dapple.yaml > secrets/dapple.yaml.new && mv secrets/dapple.yaml.new secrets/dapple.yaml
```

Through a `.new` file, so a failed `ssh` leaves yours as they were. They
are the new public key and an encrypted file: nothing secret travels.

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
the tailnet works again: until then, `ssh dapple` reaches it over the LAN,
from home. Dapple has to be at 100.64.0.1, where its
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
services. If something else still has their data open, such as Zotero on
rocinante, it starts them again and says what, changing nothing: close it
and run it again. Otherwise it swaps their data in, loads what is backed
up as a dump (Immich's database), and starts them again. What it replaced
is kept in `/persist/.offsite-restore-old-<time>` until you delete it. The
same command repairs a single service on a running host.

It restores the newest snapshot, after showing the last few with their
sizes. Restore before the reinstalled host's first night: its nightly backup
then saves the services' new, empty folders as the newest snapshot, which
its size gives away. After that, pick the one from before the reinstall:

```sh
sudo offsite-restore --snapshot <id>
```

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
`modules/hosts/<hostname>/facter.json` with the new key's files, the same
way ([Install](#install)).

## Losing a machine

Nothing needed to recover lives only on rocinante: the SSH keys are in
Bitwarden, the configuration is on Codeberg, the data on Storj, and the
YubiKeys are separate devices.

Either YubiKey (dapple's with its PIN), or the passphrase identity, opens
both hosts' secrets for the installer ([Secrets and keys](secrets.md)). It
gives a reinstalled host a new age key of its own
([A new host key](secrets.md#a-new-host-key)), so its services need no
YubiKey.

- **rocinante.** On its replacement, with a YubiKey: boot the ISO
  (a stock NixOS ISO with the `nix run` command above works too), and run
  `install-host --new-hardware rocinante` on its console. After the first
  boot, commit and push `facter.json` with the new key's files, and run
  `sudo offsite-restore`. Only what rocinante's backup holds comes back:
  Zotero, and its place on the tailnet.
- **A stolen rocinante.** Its disk unlocks with the TPM for whoever boots
  it, into a locked session, so count what is on it as known: its secrets,
  its tailnet node and its Storj credentials. Install
  its replacement as above, with these differences:
  1. Before installing, delete its node on dapple
     (`sudo headscale nodes list` for its ID, then
     `sudo headscale nodes delete -i <id>`). Restore only Zotero,
     `sudo offsite-restore other`, not `tailscale`, which would bring back
     the stolen node's key. Join the tailnet as a new host
     ([Joining the tailnet](#joining-the-tailnet)), and put its new address
     in place of `100.64.0.2` in the access policy and in the browser's
     `policies.nix`.
  2. Rotate its secrets: from step 3 of
     [Revoking a lost or compromised key](secrets.md#revoking-a-lost-or-compromised-key),
     with `sops rotate -i secrets/rocinante.yaml` and new values for what
     is in it. The installer has already replaced its old age key. Its
     `gatus_push_token` is `gatus_push_token_rocinante` in
     `secrets/dapple.yaml` too: change both, and push.
  3. Revoke its Storj credentials and make new ones
     ([Storj credentials](secrets.md#storj-credentials)).
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
  has the tools. Run `sops updatekeys` from the clone's `secrets/`, where
  it finds `.sops.yaml`.

That last case depends on your phone. An offline copy of the passphrase
identity and your Bitwarden recovery details, kept somewhere safe, removes
that dependency.

## Losing an upstream

dapple keeps a copy of every input in `flake.lock`, both hosts' and the
inputs' own, in `/var/lib/flake-archive`, and backs it up offsite with its
services. It's refreshed on each deploy that changes the lock. Each node of
the lock has a folder there, by its name in the lock: `nodes.root.inputs`
names the flake's own inputs' nodes, and an input's own input has a node
of its own, such as personal-blog's `nixpkgs`, which is `nixpkgs_2`
(`nodes.personal-blog.inputs`). dapple's build needs every node in the
lock, even one nothing uses, like niri-flake's `niri-unstable`, so one
that is gone needs its copy too.

If an input's forge or repository is gone, or a tag was moved, build from
its copy, on rocinante:

1. Copy the node's folder over. tar keeps the tree as it is, its links
   included, so it still matches the lock:

   ```sh
   mkdir -p ~/flake-archive
   ssh nixos@dapple tar -C /var/lib/flake-archive -c <node> | tar -x -C ~/flake-archive
   ```

2. Look up the node's `rev` and `lastModified` in the lock, and its
   `revCount` if it has one (a git input):

   ```sh
   nix eval --impure --expr '(builtins.fromJSON (builtins.readFile /etc/nixos/flake.lock)).nodes.<node>.locked'
   ```

3. Lock the input to the copy, with those, adding `&revCount=<revCount>`
   if it has one. `<input>` is its path, such as `nixpkgs` or
   `personal-blog/nixpkgs`:

   ```sh
   nix flake lock /etc/nixos --override-input <input> "path:$HOME/flake-archive/<node>?rev=<rev>&lastModified=<lastModified>"
   ```

   The copy has no git history, so without them nixpkgs's version label
   reads `19700101.dirty`, and every store path changes. With them, the
   hosts build exactly as before.

4. Commit `flake.lock`, as `nswitch` refuses uncommitted changes. Builds
   keep the override, but `nupdate` would lock the input from its old URL
   again, and fail: until it has a new home, update the other inputs by
   name (`nix flake update <input> ...`).

The override only works where the copy is. To give the input a new home,
make the copy a repository of your own on Codeberg (`git init`, commit,
push), point its `url` in `flake.nix` there, and
`nix flake update <input>`. For an input's own input, the new URL goes in
that input's `flake.nix`, or in a `follows` here.

With dapple gone as well, get the copy straight from the backup, the way
`offsite-prune` reaches it: `RESTIC_REPOSITORY` from dapple's
`services.restic.backups.offsite.repository`, and `restic_password`,
`storj_access_key` and `storj_secret_key` from `secrets/dapple.yaml` as
`RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Then,
in place of step 1:

```sh
restic restore latest --include /var/lib/flake-archive/<node> --target <dir>
```

The copy is then in `<dir>/var/lib/flake-archive/<node>`.

The archive holds the inputs only: not the sources their packages
download, nor cache.nixos.org's builds.
