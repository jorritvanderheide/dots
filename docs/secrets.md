# Secrets and keys

Each host has its own secrets file, `secrets/<host>.yaml`, encrypted with
[sops](https://github.com/getsops/sops) for the recipients in `.sops.yaml`.
A host only ever decrypts its own file (`/etc/sops/secrets.yaml` points at
it), so one host taken over doesn't give up the other's secrets.

`secrets/rocinante.yaml`:

- **rocinante's YubiKey**, its no-PIN identity, which the laptop decrypts
  with at boot and you edit with.
- **A passphrase identity**, as a fallback, kept in Bitwarden.

`secrets/dapple.yaml`:

- **dapple's own age key**, in `/persist/system/var/lib/sops/age.key` on
  its encrypted disk, which the server decrypts with at boot. The disk
  unlocks with the TPM, so the key is as safe as the TPM binding.
- **The admin identity**, on rocinante's YubiKey, with PIN and touch: how
  you edit the server's secrets. The laptop's own no-PIN identity can't, so
  a stolen laptop with its YubiKey doesn't open the server.
- **dapple's YubiKey**, no PIN and no touch, as an offline spare: kept
  away from the server, for reinstalling it without rocinante.
- **The passphrase identity.**

Within a file, any one recipient can decrypt on its own. sops's default
`shamir-secret-sharing-threshold=0` means no threshold is enforced within a
`key_groups` entry. So losing a key doesn't lock you out, and adding one is
additive, not a replacement.

The no-PIN YubiKey identities have physical possession as their only gate,
the same as FIDO2 LUKS unlock at boot. On a running host only root (the
services that decrypt) and a desktop session can reach the YubiKey: any
other process could otherwise decrypt everything the key can. The
passphrase identity only works where `SOPS_AGE_KEY_FILE` points at it: the
installer and `sops` by hand, not a running host's services.

## Changing a secret

```sh
nix develop       # sops, age-plugin-yubikey, pcsclite
sops secrets/rocinante.yaml
sops secrets/dapple.yaml   # asks for the YubiKey's PIN, then a touch
```

The user passwords (`user_password_<user>`) are password *hashes*, not
plaintext. Make one with `mkpasswd -m yescrypt`. `bazarr_password` is the
md5 hex digest of the password (`printf '%s' '<password>' | md5sum`),
which is what Bazarr compares.

## Enrolling an additional YubiKey

```sh
age-plugin-yubikey --generate --pin-policy never --touch-policy never
```

This matches the existing keys' no-PIN, no-touch policy. Then:

1. Add the new `age1yubikey1...` recipient to the *same* `key_groups` entry
   in `.sops.yaml`, for the file it should open. Not a new group: that would
   require *both* keys to decrypt instead of either.
2. `sops updatekeys secrets/<host>.yaml` to re-encrypt for the new set of
   recipients.
3. Push, and deploy every host (`nswitch`, `ndeploy dapple`): each decrypts
   the file it was built with.
4. Verify: unplug the old key, plug in only the new one, and confirm a
   secret still decrypts, for example with
   `sudo systemctl restart set-password-jorrit` and
   `journalctl -u set-password-jorrit`.

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

## A new host key

dapple's own key is a plain `age-keygen` identity. A reinstalled dapple
needs a new one: the installer decrypts with a YubiKey or the passphrase,
and the first boot does too, with dapple's spare YubiKey plugged in. Then:

```sh
sudo install -d -m 0700 /persist/system/var/lib/sops
sudo nix shell nixpkgs#age -c age-keygen -o /persist/system/var/lib/sops/age.key  # prints the public key
sudo chmod 0400 /persist/system/var/lib/sops/age.key
```

Replace `dapple_host` in `.sops.yaml` with the printed `age1...` key, run
`sops updatekeys secrets/dapple.yaml` from rocinante (PIN and touch), push,
and `ndeploy dapple`.

## Revoking a lost or compromised key

1. Remove its recipient from `.sops.yaml`.
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
   credentials, the user password hashes, and the tokens and API keys.
5. Push, and deploy every host.

## Regenerating the passphrase identity

`jorrit_passphrase` in `.sops.yaml` is a plain `age-keygen` identity. The
raw `AGE-SECRET-KEY-1...` text is a Bitwarden secure note and is not
committed anywhere. To rotate it:

1. `age-keygen -o new-identity.txt` to generate a fresh identity.
2. Replace the `jorrit_passphrase` anchor in `.sops.yaml` with the new
   `age1...` recipient that `age-keygen` printed.
3. `sops updatekeys` both files.
4. Save the new `AGE-SECRET-KEY-1...` line to Bitwarden, delete the old
   note, and delete `new-identity.txt`.

## Using the passphrase identity by hand

If no YubiKey is at hand, for example for an install away from home, get the
secret key text from Bitwarden, save it to a file, and point
`SOPS_AGE_KEY_FILE` at it before running `install` or `sops -d`. Both read
it from the environment when it is set:

```sh
export SOPS_AGE_KEY_FILE=/path/to/passphrase-identity.txt
```
