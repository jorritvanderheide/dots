#!/usr/bin/env bash
# Re-enroll the TPM2 LUKS keyslot -- run on the host itself, as root, any
# time the TPM state changes (e.g. after a firmware update or reset). The
# first boot with secure boot on enrolls it by itself.
set -euo pipefail

[[ $EUID -eq 0 ]] || {
  echo "Run as root" >&2
  exit 1
}

# The slot is bound to PCR 7, secure boot's state: enrolled with it off, it
# would stop unlocking once it's on. tpm2-luks-enroll skips itself then.
[[ $(bootctl status 2>/dev/null) == *"Secure Boot: enabled"* ]] || {
  echo 'Secure boot is off: turn it on first (docs/install.md, "Secure boot")' >&2
  exit 1
}

rm -f /var/lib/tpm2-luks-enroll/done
systemctl restart tpm2-luks-enroll
echo "Re-enrolled. journalctl -u tpm2-luks-enroll if it didn't take."
