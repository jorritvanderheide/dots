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

identity=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}")
trap 'rm -f "$identity"' EXIT
age-plugin-yubikey --identity >"$identity" 2>/dev/null || true
# dapple's file asks for the admin key's PIN and a touch.
RESTIC_PASSWORD=$(SOPS_AGE_KEY_FILE=$identity sops -d --extract '["restic_password"]' "$flake/secrets/$host.yaml")
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
