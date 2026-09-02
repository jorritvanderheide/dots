<div align="center">
   <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="96px" height="96px" />
   <br>
   <br>
   <h1>
      Jorrit's NixOS configuration & dots
      <br>
      <br>
   </h1>
</div>


Minimal, reproducible NixOS flake for rocinante (and eventually dapple).
flake-parts + `import-tree` auto-discovery, ZFS-on-LUKS with `preservation`
for root-rollback impermanence, TPM2 auto-unlock, and secrets encrypted in
git with sops-nix.

## Install

Boot a NixOS live ISO on the target machine (network + YubiKey plugged in),
then, with no local checkout needed:

```
sudo nix --extra-experimental-features 'nix-command flakes' \
  run "git+https://codeberg.org/BW20/dots#install" -- <hostname>
```

This partitions/formats the disk (disko, after a `yes` confirmation since it
wipes the disk) and runs `nixos-install` with no interactive root-password
prompt. First boot needs the LUKS password typed by hand once. TPM2
auto-unlock is *not* enrolled automatically -- once logged in, run
`nix run .#enroll-tpm` on the host itself to bind a keyslot. Same command
re-enrolls later (e.g. after a firmware/TPM reset).

Neither `root` nor `jorrit` can reliably get their sops-encrypted password inside
`nixos-install`'s bare chroot (no systemd there, so pcscd's socket
activation for the YubiKey doesn't apply) -- both accounts are left locked
by the installer. The same bare-chroot limitation applies on *every* real
boot too, not just install: `boot.initrd.systemd.enable` (needed for the
ZFS rollback) means each boot's activation runs chrooted into /sysroot from
the initrd, before real systemd/pcscd exist there. So `set-password-root`,
`set-password-jorrit`, and `tpm2-luks-enroll` don't rely on sops-nix's
activation-time install at all -- each decrypts its own secret directly
(`sops -d --extract`) once it's running as a real service under the booted
system's own systemd, after `pcscd.service`. Log in as `jorrit` (or `root`)
once that's had a moment to run after boot.

For the same bare-chroot reason, `nixos-install` prints `Activation script
snippet 'setupSecrets' failed (1)` / "0 successful groups required, got 0"
and finishes with "finalized with 1 error" -- expected, not a sign the
install failed. Only `luks_password` needs to decrypt during install, and
`install.sh` extracts that one separately (with pcscd started by hand)
before `nixos-install` ever runs.

If disko's `zpool create` fails with "The ZFS modules cannot be auto-loaded",
just run the same `install` command again -- the module is loaded as a
side effect of the first attempt, so the retry succeeds.

Onboarding a brand-new host (one with no `modules/hosts/<hostname>/facter.json`
committed yet) needs a local, writable checkout instead -- the script writes
the gathered hardware report back to the repo, which a read-only fetched
flake can't do:

```
git clone <repo> && cd dots
sudo INSTALL_HOST_FLAKE_DIR="$PWD" nix run .#install -- <hostname>
```
then commit and push the new `facter.json` before reinstalling that host.

## Key management

Secrets in `secrets/secrets.yaml` are encrypted for two recipients declared
in `.sops.yaml`: the YubiKey (day-to-day) and a passphrase-based identity
kept as a fallback. Either can decrypt independently (sops's default
`shamir-secret-sharing-threshold=0` means no threshold is enforced within a
`key_groups` entry), so losing the YubiKey doesn't lock you out, and adding
a second YubiKey is additive, not a replacement.

### Enrolling an additional YubiKey

```
age-plugin-yubikey --generate --pin-policy never --touch-policy never
```

matching the existing key's no-PIN/no-touch policy (physical possession is
the only gate, same as FIDO2 LUKS unlock). Then:

1. Add the new `age1yubikey1...` recipient to the *same* `key_groups` entry
   in `.sops.yaml` (not a new group -- a new group would require *both*
   keys to decrypt instead of either).
2. `sops updatekeys secrets/secrets.yaml` to re-encrypt for the new
   recipient set.
3. Append the new `AGE-PLUGIN-YUBIKEY-...` identity line (printed by
   `--generate`) to `secrets/yubikey-identity.txt`.
4. `nswitch` (or `nixos-rebuild switch`) so `/etc/sops/yubikey-identity.txt`
   picks up the new line.
5. Verify: unplug the primary key, plug in only the new one, confirm a
   secret still decrypts (e.g. `sudo systemctl restart set-password-jorrit`
   and check `journalctl -u set-password-jorrit`).

### Revoking a lost or compromised YubiKey

1. Remove its recipient anchor from `.sops.yaml`.
2. `sops updatekeys secrets/secrets.yaml`.
3. Remove its identity line from `secrets/yubikey-identity.txt`.
4. `nswitch`.

### Regenerating the passphrase fallback identity

`jorrit_passphrase` in `.sops.yaml` is a plain `age-keygen` identity; the
raw `AGE-SECRET-KEY-1...` text is stored as a Bitwarden secure note, not
committed anywhere. To rotate it:

1. `age-keygen -o new-identity.txt` to generate a fresh identity.
2. Replace the `jorrit_passphrase` anchor in `.sops.yaml` with the new
   `age1...` recipient printed by `age-keygen`.
3. `sops updatekeys secrets/secrets.yaml`.
4. Save the new `AGE-SECRET-KEY-1...` line to Bitwarden, delete the old
   note, and delete `new-identity.txt` locally.

### Using the passphrase identity manually

If the YubiKey isn't available (e.g. during a fresh install away from
home), retrieve the secret key text from Bitwarden, save it to a local
file, and point `SOPS_AGE_KEY_FILE` at it before running `install.sh` or
any manual `sops -d` command -- both already read `SOPS_AGE_KEY_FILE` from
the environment if it's set:

```
export SOPS_AGE_KEY_FILE=/path/to/passphrase-identity.txt
```
