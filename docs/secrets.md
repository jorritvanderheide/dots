# Secrets and keys

Each host has its own secrets file, `secrets/<host>.yaml`, encrypted with
[sops](https://github.com/getsops/sops) for the recipients in
`secrets/.sops.yaml`. A host only ever decrypts its own file
(`sops.defaultSopsFile` points at it), so one host taken over doesn't give
up the other's secrets.

Each host decrypts at activation (every boot and switch) with an age key of
its own, in `/persist/system/var/lib/sops/age.key` on its encrypted disk,
readable by root only. The disk unlocks with the TPM only under our own secure boot,
so the key is as safe as that binding. No host needs a YubiKey to boot.

There are two YubiKeys, and they open the same: either one does
everything, so losing one loses nothing. Each holds two identities, a
no-PIN one and a PIN one (`secrets/.sops.yaml` has their slots).

`secrets/rocinante.yaml`:

- **rocinante's own age key.**
- **Both YubiKeys' no-PIN identities**: how you edit the laptop's secrets.
- **A passphrase identity**, as a fallback, kept in Bitwarden.

`secrets/dapple.yaml`:

- **dapple's own age key.**
- **Both YubiKeys' PIN identities**, with PIN and touch: how you edit the
  server's secrets. The no-PIN identities can't, so a stolen laptop with a
  YubiKey still in doesn't open the server.
- **The passphrase identity.**

Within a file, any one recipient can decrypt on its own. sops's default
`shamir-secret-sharing-threshold=0` means no threshold is enforced within a
`key_groups` entry. So losing a key doesn't lock you out, and adding one is
additive, not a replacement.

The no-PIN YubiKey identities have physical possession as their only gate.
On a running host only root and a desktop session can reach the YubiKey:
any other process could otherwise decrypt everything the key can. The
passphrase identity only works where `SOPS_AGE_KEY_FILE` points at it: the
installer and `sops` by hand, not a running host's services.

## Changing a secret

```sh
nix develop       # sops, age-plugin-yubikey, pcsclite
sops secrets/rocinante.yaml
sops secrets/dapple.yaml   # asks for the YubiKey's PIN, then a touch
```

Editing needs no `secrets/.sops.yaml`: each file lists its own recipients.
`sops updatekeys` and a new file do, and sops only looks for it from the
current directory up. The dev shell sets `SOPS_CONFIG` to it; without the
dev shell, run those from `secrets/`.

The user passwords (`user_password_<user>`) are password *hashes*, not
plaintext. Make one with `mkpasswd -m yescrypt`. `bazarr_password` is the
md5 hex digest of the password (`printf '%s' '<password>' | md5sum`),
which is what Bazarr compares.

`ssh_host_key` is dapple's SSH host key, the whole private key file, so a
reinstalled dapple is the host rocinante pins from its first boot. Its
public half is `site.dapple.hostKey` in `modules/flake/site.nix`, and the
two have to match, or rocinante refuses the next deploy's SSH. Check before
deploying a new one:

```fish
ssh-keygen -y -f (sops -d --extract '["ssh_host_key"]' secrets/dapple.yaml | psub)
```

A new one comes from `ssh-keygen -t ed25519 -N "" -C root@dapple -f key`:
`key` goes in the secret and `key.pub` in `site.nix`, in the same deploy.

## Enrolling an additional YubiKey

A new key, or one replacing a lost one, gets what the others have. First
its PIV PIN, PUK and management key, none of them the factory default
(`ykman piv info` warns about any that still is): a default PUK lets
whoever holds the key set a new PIN. Then its two identities:

```sh
age-plugin-yubikey --generate --pin-policy never --touch-policy never
age-plugin-yubikey --generate --pin-policy once --touch-policy cached
```

Its FIDO2 PIN, and its FIDO2 slot on rocinante's disk, with only this key
plugged in. A key shows up twice, over USB and through pcscd, so `auto`
refuses to pick: name its `/dev/hidraw*` path from the list.

```sh
systemd-cryptenroll --fido2-device=list
sudo systemd-cryptenroll --fido2-device=/dev/hidrawN --fido2-with-client-pin=yes \
  --fido2-with-user-presence=yes /dev/disk/by-partlabel/disk-main-luks
```

And its FIDO2 key for sudo on dapple, whose `.pub` goes in
`lib.sudoKeys` (then `systemctl --user restart ssh-agent-sudo` loads it):

```sh
ssh-keygen -t ed25519-sk -O application=ssh:dapple-sudo -N "" \
  -f ~/.ssh/dapple-sudo-<serial>
```

Then:

1. Add the no-PIN `age1yubikey1...` recipient to `rocinante.yaml`'s
   `key_groups` entry in `secrets/.sops.yaml`, and the PIN one to
   `dapple.yaml`'s.
   The *same* entry, not a new group: that would require *both* keys to
   decrypt instead of either.
2. `sops updatekeys secrets/<host>.yaml`, for both files, to re-encrypt for
   the new set of recipients.
3. Push, and deploy every host (`nswitch`, `ndeploy dapple`): each decrypts
   the file it was built with.
4. Verify: unplug the old key, plug in only the new one, and decrypt a
   secret in the dev shell, for example
   `sops -d --extract '["restic_password"]' secrets/<host>.yaml >/dev/null`.
   (The hosts' services decrypt with their own age keys, so they don't
   tell.)

## Storj credentials

The offsite backups are in the `offsite` bucket, one restic repository per
host under `restic/<host>/`. Each host's `storj_access_key` and
`storj_secret_key` are S3 credentials that reach only its own folder and
can't delete, which on Storj also means they can't overwrite: ransomware on
a host can't wipe its backups ([Security](security.md)). The owner's
access grant (`offsite-owner` in the Storj console) and its S3 key can do
everything, so they are in Bitwarden only, never on a host:
`nix run .#offsite-prune -- <host>` asks for that key.

New credentials for a host, from the owner's grant (not a new one made in
the console):

```sh
nix shell nixpkgs#storj-uplink
uplink access import owner -f          # the grant from Bitwarden
uplink access restrict --access owner --readonly=false --disallow-deletes \
    --prefix sj://offsite/restic/<host>/ --import-as <host>-backup -f >/dev/null
uplink access register <host>-backup --format env > $XDG_RUNTIME_DIR/storj.env
```

Copy the two values from that file into `secrets/<host>.yaml`, then delete
it. Revoke old ones with `uplink access revoke --access owner <name>`.

### A first or very large backup

Without delete rights, restic can't refresh its lock, and gives up after
22.5 minutes. A daily run is far shorter, and a cut-off run resumes on the
retry, but the first backup into a new repository (a new host or bucket)
or an import of tens of GB can loop: each retry re-sends what the last one
hadn't indexed, and is cut off again just before saving its snapshot. (A
reinstalled host's restored data is in its repository already.) Then run
it once with the
owner's key, through the normal service (so it still reads a snapshot of
`/persist`), on the host. A backup stopped by hand counts as a failed one:
Gatus alerts, and it is tried again 5 minutes later, from
`offsite-backup-retry.timer`. Stopping the backup starts that timer, so
stop the timer after it:

```sh
sudo systemctl stop restic-backups-offsite
sudo systemctl stop offsite-backup-retry.timer
sudo bash -c 'umask 077; read -p "owner access key: " a; read -sp "owner secret key: " s; echo; printf "AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n" "$a" "$s" > /run/secrets/rendered/restic-s3-env'
sudo systemctl start --no-block restic-backups-offsite
journalctl -fu restic-backups-offsite         # until: snapshot ... saved
sudo /run/current-system/activate             # the host's own key again
```

Don't deploy meanwhile: that can put the host's key back halfway.

## A new host key

A host's own key is a plain `age-keygen` identity. The installer makes a
new one for every host it installs: it replaces `<host>_host` in the
clone's `secrets/.sops.yaml` with it, re-encrypts `secrets/<host>.yaml`
with the YubiKey (or passphrase) it decrypts with, and puts the key in
`/persist/system/var/lib/sops/age.key`. Commit and push both files after
the first boot: from the host's `/etc/nixos`, or for dapple, which has no
git, from rocinante ([Install](install.md#install) has the commands).

It has to happen there, not after the first boot: without its secrets a
host's accounts stay locked, and no service can type the PIN that dapple's
file needs.

To replace the key of a running host by hand, on the host:

```sh
sudo install -d -m 0700 /persist/system/var/lib/sops
sudo nix shell nixpkgs#age -c age-keygen -o /persist/system/var/lib/sops/age.key  # prints the public key
sudo chmod 0400 /persist/system/var/lib/sops/age.key
```

Replace `<host>_host` in `secrets/.sops.yaml` with the printed `age1...`
key, run `sops updatekeys secrets/<host>.yaml` from rocinante (for
dapple's, with a YubiKey's PIN and a touch), push, and deploy (`nswitch`,
or `ndeploy dapple`).

## Revoking a lost or compromised key

1. Remove its recipient from `secrets/.sops.yaml`.
2. `sops updatekeys secrets/<host>.yaml` for every file it was a recipient of.
3. `sops rotate -i secrets/<host>.yaml`. `updatekeys` alone keeps the same
   data key, and the lost key still unwraps that key from any old copy of
   the file, such as the repository's history on Codeberg. With it, the
   key also decrypts every value written after the revocation. `rotate`
   makes a new data key.
4. Change the secrets themselves: the old copies still open with the lost
   key. In particular, change the LUKS password (`cryptsetup luksChangeKey`
   on every disk, then `sudo enroll-tpm`), the restic password
   (`restic key add`, then `restic key remove` the old one), the Storj
   credentials, the user password hashes, dapple's SSH host key, and the
   tokens and API keys.
5. Push, and deploy every host.

## Regenerating the passphrase identity

`jorrit_passphrase` in `secrets/.sops.yaml` is a plain `age-keygen`
identity. The raw `AGE-SECRET-KEY-1...` text is a Bitwarden secure note and
is not committed anywhere. To rotate it:

1. `age-keygen -o new-identity.txt` to generate a fresh identity.
2. Replace the `jorrit_passphrase` anchor in `secrets/.sops.yaml` with the
   new `age1...` recipient that `age-keygen` printed.
3. `sops updatekeys` both files.
4. Save the new `AGE-SECRET-KEY-1...` line to Bitwarden, delete the old
   note, and delete `new-identity.txt`.

## Using the passphrase identity by hand

If no YubiKey is at hand, for example for an install away from home, get the
secret key text from Bitwarden, save it to a file, and point
`SOPS_AGE_KEY_FILE` at it before running `install`, `offsite-prune` or
`sops -d`. They read it from the environment when it is set:

```sh
export SOPS_AGE_KEY_FILE=/path/to/passphrase-identity.txt
```
