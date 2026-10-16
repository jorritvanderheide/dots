# shellcheck shell=bash disable=SC2154 # entry_units, persisted: from the module
# Restores services' data from the offsite backup (restic on Storj): every
# entry of my.offsite-backup, or the ones named. It downloads everything
# first, so a failed download changes nothing. Then it stops the entries'
# units, swaps their data in, runs their restore commands and starts them
# again. What it replaced is kept under /persist/.offsite-restore-old-<time>,
# and the run is logged to /var/log/offsite-restore.log.
#
# Usage: offsite-restore [--target DIR] [--snapshot ID] [ENTRY...]
#   --target DIR     only download into DIR, and change nothing else
#   --snapshot ID    restore that snapshot instead of the newest one
#
# The offsite-backup module puts entry_paths, entry_units, persisted and
# run_hook in front of this, from the host's entries.
#
# --no-lock: the host's credentials can't delete, so restic couldn't
# refresh a lock and would give up on a restore longer than 22 minutes.
# Nothing removes data meanwhile: only offsite-prune can, from rocinante.

# What it downloads and what it replaces come out of folders only their
# service can read, and land in folders it makes: root's alone, like the
# log. restic sets the restored files' own modes.
umask 077

staging=/persist/.offsite-restore

usage() {
  echo "Usage: offsite-restore [--target DIR] [--snapshot ID] [ENTRY...]"
  echo "Entries: ${!entry_paths[*]}"
}

target=""
snapshot=latest
while [[ $# -gt 0 ]]; do
  case $1 in
  --target)
    target=${2:?--target needs a directory}
    shift 2
    ;;
  --snapshot)
    snapshot=${2:?--snapshot needs a snapshot ID}
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
  echo "No backup credentials: the host's secrets weren't decrypted at activation." >&2
  exit 1
}

includes=()
for path in "${paths[@]}"; do
  includes+=(--include "$path")
done

# restic restores nothing for a path the snapshot doesn't have, and still
# succeeds, as for a service added after it.
check_restored() {
  for path in "${paths[@]}"; do
    if [[ ! -d $1$path ]]; then
      echo "${path} is not in snapshot ${snapshot}. Nothing was changed." >&2
      exit 1
    fi
  done
}

if [[ -n $target ]]; then
  restic-offsite restore --no-lock "$snapshot" --target "$target" "${includes[@]}"
  check_restored "$target"
  exit 0
fi

# A reinstalled host's first nightly backup holds its services' new, empty
# folders, so after that night the newest snapshot isn't the one to bring
# back: its size gives it away.
restic-offsite snapshots --no-lock --compact --latest 5
if [[ $snapshot == latest ]]; then
  echo "This replaces the data of ${names[*]} with the newest snapshot, the last one above."
else
  echo "This replaces the data of ${names[*]} with snapshot ${snapshot}."
fi
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
restic-offsite restore --no-lock "$snapshot" --target "$staging" "${includes[@]}"
check_restored "$staging"

old=/persist/.offsite-restore-old-$(date +%Y%m%dT%H%M%S)
systemctl stop restic-backups-offsite.timer offsite-backup-retry.timer "${units[@]}"

# What the entries' units don't cover would go on writing into the data
# while it's swapped: Zotero, a desktop app, or a comics conversion its
# timer started (a conversion isn't in the units, as starting them again
# would run one).
open=()
for path in "${paths[@]}"; do
  mapfile -t -O "${#open[@]}" open < <(lsof -w -t +D "${persisted[$path]}" || true)
done
if ((${#open[@]})); then
  echo "Still in use by:" >&2
  ps -o pid=,comm= -p "$(
    IFS=,
    echo "${open[*]}"
  )" >&2 || true
  systemctl start "${units[@]}" restic-backups-offsite.timer
  echo "Close those and run it again. Nothing was changed." >&2
  exit 1
fi

# errtrace: the restore commands run inside run_hook, where the trap
# wouldn't fire otherwise.
set -E
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
