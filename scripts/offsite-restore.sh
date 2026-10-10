# Restores services' data from the offsite backup (restic on Storj): every
# entry of my.offsite-backup, or the ones named. It downloads everything
# first, so a failed download changes nothing. Then it stops the entries'
# units, swaps their data in, runs their restore commands and starts them
# again. What it replaced is kept under /persist/.offsite-restore-old-<time>,
# and the run is logged to /var/log/offsite-restore.log.
#
# Usage: offsite-restore [--target DIR] [ENTRY...]
#   --target DIR   only download into DIR, and change nothing else
#
# The offsite-backup module puts entry_paths, entry_units, persisted and
# run_hook in front of this, from the host's entries.

staging=/persist/.offsite-restore

usage() {
  echo "Usage: offsite-restore [--target DIR] [ENTRY...]"
  echo "Entries: ${!entry_paths[*]}"
}

target=""
while [[ $# -gt 0 ]]; do
  case $1 in
  --target)
    target=${2:?--target needs a directory}
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    usage >&2
    exit 1
    ;;
  *) break ;;
  esac
done

names=("$@")
[[ ${#names[@]} -gt 0 ]] || names=("${!entry_paths[@]}")
paths=()
units=()
for name in "${names[@]}"; do
  if [[ ! -v entry_paths[$name] ]]; then
    echo "No entry ${name}." >&2
    usage >&2
    exit 1
  fi
  read -ra entry <<<"${entry_paths[$name]}"
  paths+=("${entry[@]}")
  read -ra entry <<<"${entry_units[$name]}"
  units+=("${entry[@]}")
done

[[ $EUID -eq 0 ]] || {
  echo "Run as root." >&2
  exit 1
}
[[ -r /run/secrets/restic_password ]] || {
  echo "No backup credentials yet: systemctl start offsite-backup-secrets" >&2
  exit 1
}

includes=()
for path in "${paths[@]}"; do
  includes+=(--include "$path")
done

if [[ -n $target ]]; then
  restic-offsite restore latest --target "$target" "${includes[@]}"
  exit 0
fi

echo "This replaces the data of: ${names[*]}"
read -rp "Type 'yes' to continue: " confirm
[[ $confirm == "yes" ]] || exit 1

# From here on, survive a dropped SSH session: restoring Tailscale or
# Headscale can cut your own. Hangups are ignored, and tee keeps writing
# the output to the log when the terminal is gone.
log=/var/log/offsite-restore.log
trap '' HUP
exec > >(tee --output-error=warn -a "$log") 2>&1
echo "Restoring ${names[*]}, $(date). Also logged to ${log}."

rm -rf "$staging"
restic-offsite restore latest --target "$staging" "${includes[@]}"
for path in "${paths[@]}"; do
  if [[ ! -d $staging$path ]]; then
    echo "${path} is not in the backup. Nothing was changed." >&2
    exit 1
  fi
done

old=/persist/.offsite-restore-old-$(date +%Y%m%dT%H%M%S)
systemctl stop restic-backups-offsite.timer "${units[@]}"
trap 'echo "Stopped halfway: ${units[*]} are still stopped, and what was replaced is in ${old}." >&2' ERR

# Through /persist, not the paths themselves: those are bind mounts, and a
# move across mounts would copy instead of rename.
for path in "${paths[@]}"; do
  live=${persisted[$path]}
  staged=$staging$path
  # A fresh install can give a service's user another ID than the backup
  # has: give the restored files to whoever owns the directory now.
  owner=$(stat -c %u:%g "$live")
  restored=$(stat -c %u:%g "$staged")
  [[ $owner == "$restored" ]] || chown -R --from="$restored" "$owner" "$staged"
  mkdir -p "$old$path"
  find "$live" -mindepth 1 -maxdepth 1 -exec mv -t "$old$path" {} +
  find "$staged" -mindepth 1 -maxdepth 1 -exec mv -t "$live" {} +
done

for name in "${names[@]}"; do
  run_hook "$name"
done

systemctl start "${units[@]}" restic-backups-offsite.timer
rm -rf "$staging"
echo "Done. What it replaced is in ${old}: delete it once everything works."
