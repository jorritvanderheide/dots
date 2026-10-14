#!/usr/bin/env bash
# Prunes a host's offsite backup and checks it, from rocinante. The hosts'
# own Storj credentials can't delete (see offsite-backup.nix), so they can't
# prune, nor remove the lock each backup leaves. Run every few months.
#
# Usage: nix run .#offsite-prune -- <host>
set -euo pipefail

host=${1:?usage: offsite-prune <host>}
flake=$OFFSITE_PRUNE_FLAKE

repository=$(nix eval --raw "$flake#nixosConfigurations.$host.config.services.restic.backups.offsite.repository")

# Whichever YubiKey is plugged in, unless SOPS_AGE_KEY_FILE already
# points at an identity, like the passphrase one (docs/secrets.md).
if [[ -z ${SOPS_AGE_KEY_FILE:-} ]]; then
  SOPS_AGE_KEY_FILE=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}")
  export SOPS_AGE_KEY_FILE
  trap 'rm -f "$SOPS_AGE_KEY_FILE"' EXIT
  age-plugin-yubikey --identity >"$SOPS_AGE_KEY_FILE" 2>/dev/null || true
  grep -q '^AGE-PLUGIN-YUBIKEY-' "$SOPS_AGE_KEY_FILE" || {
    echo "No YubiKey found. Plug one in, or set SOPS_AGE_KEY_FILE to the passphrase identity." >&2
    exit 1
  }
fi
# dapple's file asks for the YubiKey's PIN and a touch.
RESTIC_PASSWORD=$(sops -d --extract '["restic_password"]' "$flake/secrets/$host.yaml")
export RESTIC_PASSWORD RESTIC_REPOSITORY=$repository

# The owner's credentials, from Bitwarden: they can delete, so they are
# never stored on a host.
read -rp "Storj owner access key: " AWS_ACCESS_KEY_ID
read -rsp "Storj owner secret key: " AWS_SECRET_ACCESS_KEY
echo
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

restic unlock
# shellcheck disable=SC2086 # one word per option
restic forget --prune $OFFSITE_PRUNE_KEEP
restic check
