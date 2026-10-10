# Secrets and keys

Secrets live in `secrets/secrets.yaml`, encrypted with
[sops](https://github.com/getsops/sops) for the recipients in `.sops.yaml`:

- **rocinante's YubiKey**, for day-to-day use.
- **dapple's own YubiKey**, plugged in permanently so it boots headless.
- **A passphrase identity**, as a fallback, kept in Bitwarden.

Any one of them can decrypt on its own. sops's default
`shamir-secret-sharing-threshold=0` means no threshold is enforced within a
`key_groups` entry. So losing a YubiKey doesn't lock you out, and adding one
is additive, not a replacement.

The YubiKeys use no PIN and no touch: physical possession is the only gate,
the same as FIDO2 LUKS unlock at boot. The hosts, the installer and the dev
shell decrypt with whichever YubiKey is plugged in, so any of them works on
any host. The passphrase identity only works where `SOPS_AGE_KEY_FILE` points
at it: the installer and `sops` by hand, not a running host's services.

## Changing a secret

```sh
nix develop       # sops, age-plugin-yubikey, pcsclite
sops secrets/secrets.yaml
```

The user passwords (`user_password_<user>`) are password *hashes*, not
plaintext. Make one with `mkpasswd -m yescrypt`.

## Enrolling an additional YubiKey

```sh
age-plugin-yubikey --generate --pin-policy never --touch-policy never
```

This matches the existing keys' no-PIN, no-touch policy. Then:

1. Add the new `age1yubikey1...` recipient to the *same* `key_groups` entry
   in `.sops.yaml`. Not a new group: that would require *both* keys to
   decrypt instead of either.
2. `sops updatekeys secrets/secrets.yaml` to re-encrypt for the new set of
   recipients.
3. Push, and deploy every host (`nswitch`, `ndeploy dapple`): each decrypts
   the `secrets.yaml` it was built with.
4. Verify: unplug the old key, plug in only the new one, and confirm a
   secret still decrypts, for example with
   `sudo systemctl restart set-password-jorrit` and
   `journalctl -u set-password-jorrit`.

## Revoking a lost or compromised YubiKey

1. Remove its recipient from `.sops.yaml`.
2. `sops updatekeys secrets/secrets.yaml`.
3. Push, and deploy every host.

## Regenerating the passphrase identity

`jorrit_passphrase` in `.sops.yaml` is a plain `age-keygen` identity. The
raw `AGE-SECRET-KEY-1...` text is a Bitwarden secure note and is not
committed anywhere. To rotate it:

1. `age-keygen -o new-identity.txt` to generate a fresh identity.
2. Replace the `jorrit_passphrase` anchor in `.sops.yaml` with the new
   `age1...` recipient that `age-keygen` printed.
3. `sops updatekeys secrets/secrets.yaml`.
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
