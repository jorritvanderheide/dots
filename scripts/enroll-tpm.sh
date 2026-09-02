#!/usr/bin/env bash
# Enroll (or re-enroll) the TPM2 LUKS keyslot -- run on the target host
# itself, as root. Not run automatically: do this once after first login,
# and again any time the TPM state changes (e.g. after a firmware reset).
set -euo pipefail

[[ $EUID -eq 0 ]] || {
  echo "Run as root" >&2
  exit 1
}

rm -f /var/lib/tpm2-luks-enroll/done
systemctl restart tpm2-luks-enroll
echo "Re-enrolled. journalctl -u tpm2-luks-enroll if it didn't take."
