#!/usr/bin/env bash
# A VM to rehearse an install in: secure boot firmware in setup mode, a
# TPM, and the host's disks under their own by-id names, so the installer
# finds the disks its hardware report names. Run on rocinante, as yourself,
# through `nix run .#install-vm`.
#
# Usage: install-vm install [--blank] [host]
#          Boot the installer ISO, with the plugged-in YubiKey and the
#          network; then `ssh -p 2222 root@localhost install-host <host>`.
#          --blank gives the main disk another serial, so the hardware
#          report's disk isn't there: the new-hardware path. QEMU exits
#          instead of rebooting, so the installed host never boots online.
#        install-vm boot [--storj] [host]
#          Boot the installed disks, offline: the host would otherwise run
#          its CI runner, report to the real status page and back up over
#          its real backup. --storj lets through the Storj gateway only,
#          for offsite-restore.
#        install-vm reset
#          Delete the VM: its disks hold the host's secrets. They live on
#          rocinante's root, so a reboot deletes them too.
set -euo pipefail

state="${XDG_CACHE_HOME:-$HOME/.cache}/dots-install-vm"
phase=${1:?usage: install-vm install [--blank] [host] | boot [--storj] [host] | reset}
shift

if [[ $phase == reset ]]; then
  rm -rf "$state"
  echo "Deleted ${state}."
  exit 0
fi

blank=false storj=false
if [[ $phase == install && ${1:-} == --blank ]]; then
  blank=true
  shift
elif [[ $phase == boot && ${1:-} == --storj ]]; then
  storj=true
  shift
fi
host=${1:-dapple}

# The disks as the host's config names them, /dev/disk/by-id/<bus>-<model>_<serial>:
# NVMe and SATA disks get the same name from QEMU's model and serial.
mkdir -p "$state"
# shellcheck disable=SC2016 # a Nix expression, interpolated by Nix
disks=$(nix eval --raw "${INSTALL_VM_FLAKE}#nixosConfigurations.${host}.config.disko.devices.disk" \
  --apply 'disks: builtins.concatStringsSep "\n" (map (name: "${name} ${disks.${name}.device} ${if name == "main" then "64G" else "8G"}") (builtins.attrNames disks))')
disk_args=()
ata_bus=0
while read -r name device size; do
  id=${device#/dev/disk/by-id/}
  bus=${id%%-*}
  rest=${id#*-}
  model=${rest%_*}
  serial=${rest##*_}
  if $blank && [[ $name == main ]]; then
    serial=VMBLANK${serial: -6}
  fi
  [[ -e "$state/$name.qcow2" ]] || qemu-img create -q -f qcow2 "$state/$name.qcow2" "$size"
  disk_args+=(-drive "if=none,id=$name,format=qcow2,file=$state/$name.qcow2")
  case $bus in
  nvme) disk_args+=(-device "nvme,drive=$name,model=$model,serial=$serial") ;;
  ata)
    disk_args+=(-device "ide-hd,drive=$name,bus=ide.$ata_bus,model=$model,serial=$serial")
    ata_bus=$((ata_bus + 1))
    ;;
  *)
    echo "Can't imitate ${device}: only nvme- and ata- names." >&2
    exit 1
    ;;
  esac
done <<<"$disks"

# Firmware variables without keys: secure boot's setup mode, where the
# host's first boots enroll their own.
[[ -e "$state/OVMF_VARS.fd" ]] || install -m 0644 "${OVMF_FD}/FV/OVMF_VARS.fd" "$state/OVMF_VARS.fd"
mkdir -p "$state/tpm"
swtpm socket --tpm2 --tpmstate "dir=$state/tpm" --ctrl "type=unixio,path=$state/tpm.sock" --daemon --terminate

# shellcheck disable=SC2054 # QEMU's options are comma-separated
args=(
  -enable-kvm -machine q35,smm=on -cpu host -smp 4 -m 8G
  -global driver=cfi.pflash01,property=secure,value=on
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_FD}/FV/OVMF_CODE.fd"
  -drive "if=pflash,format=raw,unit=1,file=$state/OVMF_VARS.fd"
  -chardev "socket,id=tpm,path=$state/tpm.sock" -tpmdev emulator,id=tpm0,chardev=tpm -device tpm-tis,tpmdev=tpm0
  -device virtio-vga -display gtk
  "${disk_args[@]}"
)

if [[ $phase == install ]]; then
  iso=$(nix build --no-link --print-out-paths "${INSTALL_VM_FLAKE}#iso")/iso/dots-installer.iso
  yubikey=""
  for device in /sys/bus/usb/devices/*; do
    [[ $(cat "$device/idVendor" 2>/dev/null) == 1050 ]] && yubikey=$(<"$device/idProduct")
  done
  [[ -n $yubikey ]] || {
    echo "Plug in a YubiKey: the installer decrypts with it." >&2
    exit 1
  }
  # The agent holds the YubiKey, which the VM needs to itself.
  systemctl --user stop yubikey-agent || true
  trap 'systemctl --user start yubikey-agent || true' EXIT
  echo "Once the ISO is up: ssh -p 2222 -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost install-host ${host}"
  qemu-system-x86_64 "${args[@]}" -no-reboot \
    -drive "if=none,id=iso,media=cdrom,readonly=on,file=$iso" -device ide-cd,drive=iso,bus=ide.5,bootindex=0 \
    -device qemu-xhci -device "usb-host,vendorid=0x1050,productid=0x$yubikey" \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22
else
  net=user,model=virtio-net-pci,restrict=on
  if $storj; then
    # The guest reaches 10.0.2.100:443, and QEMU passes that to the
    # gateway; everything else stays cut off.
    net+=",guestfwd=tcp:10.0.2.100:443-cmd:nc gateway.eu1.storjshare.io 443"
    echo "In the VM, as root, before offsite-restore (and don't leave it running at night, when the backup would run):"
    echo "  systemctl stop restic-backups-offsite.timer offsite-backup-retry.timer"
    echo "  { echo '10.0.2.100 gateway.eu1.storjshare.io'; cat /etc/hosts; } > /run/hosts && mount --bind /run/hosts /etc/hosts && systemctl restart nscd"
  fi
  qemu-system-x86_64 "${args[@]}" -nic "$net"
fi
