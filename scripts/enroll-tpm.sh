#!/usr/bin/env bash
# Re-enroll the TPM2 LUKS keyslot -- run on the host itself, as root, any
# time the TPM state changes (e.g. after a firmware reset). The first boot
# after an install enrolls it by itself.
set -euo pipefail

[[ $EUID -eq 0 ]] || {
  echo "Run as root" >&2
  exit 1
}

rm -f /var/lib/tpm2-luks-enroll/done
systemctl restart tpm2-luks-enroll
echo "Re-enrolled. journalctl -u tpm2-luks-enroll if it didn't take."
