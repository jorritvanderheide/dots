# <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="48" align="absmiddle" /> Dots

**Jorrit's NixOS configuration: a laptop to work on, and a server for the home.**

One flake for two machines. rocinante is a Framework laptop with a niri
desktop; dapple is the home server, with photos, media, passwords and a
self-hosted tailnet. Both wipe their root on every boot and keep only what is
declared, their disks unlock with the TPM under secure boot, and their
secrets are in this repository, encrypted per host. See
[Installation](#1-installation).

<br/>

![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-5277c3?style=flat-square&logo=nixos&logoColor=white)
![Hosts: rocinante and dapple](https://img.shields.io/badge/hosts-rocinante%20%7C%20dapple-5277c3?style=flat-square)
![flake-parts and import-tree](https://img.shields.io/badge/built%20with-flake--parts%20%2B%20import--tree-5277c3?style=flat-square)

<br/>

![The frame and bar, with notifications in the corner and the calendar open](https://codeberg.org/BW20/weinig-shell/raw/branch/main/images/overview.png)

| The launcher | The lock screen |
| --- | --- |
| ![The launcher along the top](https://codeberg.org/BW20/weinig-shell/raw/branch/main/images/launcher.png) | ![The lock screen](https://codeberg.org/BW20/weinig-shell/raw/branch/main/images/lock.png) |

[Weinig](https://codeberg.org/BW20/weinig-shell), the shell that rocinante runs.

<br/>

## Table of contents

- [1 Installation](#1-installation)
- [2 Hosts](#2-hosts)
- [3 Safety](#3-safety)
- [4 Commands](#4-commands)
- [5 Services on dapple](#5-services-on-dapple)
- [6 Network exposure](#6-network-exposure)
- [7 Security](#7-security)
- [8 Secrets and keys](#8-secrets-and-keys)
- [9 Recovery](#9-recovery)
- [10 Layout](#10-layout)

<br/>

## 1 Installation

Build the installer ISO and write it to a USB stick (on a
[Ventoy](https://www.ventoy.net) stick, copy the file onto it instead):

```sh
nix build .#iso
sudo dd if=result/iso/dots-installer.iso of=/dev/sdX bs=4M status=progress
```

Put the machine's firmware in secure boot setup mode first
([Secure boot](#secure-boot)): the ISO isn't signed, and a reinstalled host
makes new keys. Boot it from the stick with network (a cable, or `nmtui` on
its console) and either YubiKey plugged in, with its PIN at hand. Then,
from any computer with Bitwarden's SSH agent, or with `install-host
<hostname>` on the ISO's own console:

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

It runs in tmux, so after a dropped connection the same command takes you
back to it. It runs the installer from Codeberg's `main`, so push first;
the ISO only needs rebuilding for a change to `iso.nix` or the SSH keys in
`site.nix`, or a newer NixOS. Any other NixOS live ISO works too, from its
own console:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run "git+https://codeberg.org/BW20/dots#install" -- <hostname>
```

The installer (`scripts/install.sh`) checks that the disk the host's
hardware report names is there, by its model and serial. If it isn't, or
there is no report, it asks, then gathers this machine's report (also with
`--new-hardware`). It decrypts the LUKS password and the host's own age key
with the YubiKey, the second from `secrets/installer.yaml` with its PIN;
shows the disk it will wipe, and any it keeps (dapple's media disk, which
has no offsite copy), and waits for a `yes`; installs with disko and
`nixos-install`; pushes a new hardware report to Codeberg's `main` with the
deploy key in `secrets/installer.yaml`; and clones this repository to
`/etc/nixos`. Nothing is left to commit. The report's commit isn't
signed, so the hosts deploy it with your next signed push, which has to
build on it; the installed host already runs it. It asks before the push:
a test install, as in a VM, answers no.

### First boot

Type the LUKS password until secure boot is on: the first boot makes the
secure boot keys, the next enrolls them, and the first with secure boot on
binds the TPM, after which boots unlock by themselves.

The host decrypts its secrets with its own age key from the start, so it
needs no YubiKey. On rocinante, enroll each YubiKey's FIDO2 slot again
([Enrolling a YubiKey](#enrolling-a-yubikey)): the install made a new LUKS
header, without them. On a reinstalled host, `sudo offsite-restore` brings
the data back ([Restoring data](#restoring-data)), and with it the host's
place on the tailnet.

### Secure boot

Both hosts boot with secure boot, with keys of their own
([lanzaboote](https://github.com/nix-community/lanzaboote)), and the TPM
only unlocks the disk for a boot with those keys (PCR 7). The firmware
takes the keys once, in setup mode:

1. A configuration with lanzaboote makes the keys on its first boot or
   switch, in `/persist/system/var/lib/sbctl`.
2. In the firmware's setup, put secure boot in setup mode ("reset to setup
   mode" or "clear secure boot keys").
3. Reboot. systemd-boot enrolls the keys, with Microsoft's for the
   hardware's option ROMs, and reboots.
4. In the firmware's setup, turn secure boot on if it isn't, and set an
   administrator password, so the keys can't be cleared without it.
5. Boot. `bootctl status` shows `Secure Boot: enabled (user)`. A fresh
   install binds the TPM on this boot; on a host that had a TPM slot
   already, run `sudo enroll-tpm`.
6. Check that the TPM slot is bound to PCR 7 (`luksDump` doesn't show
   PCRs), and that a reboot unlocks by itself. This should print
   `"tpm2-pcrs":[7]`:
   ```sh
   sudo sh -c 'for i in 0 1 2; do cryptsetup token export --token-id $i /dev/disk/by-partlabel/disk-main-luks; echo; done 2>/dev/null' | grep -o '"tpm2-pcrs":\[[^]]*\]'
   ```

A firmware update (fwupd, on rocinante) or a new revocation list can change
PCR 7, and so can a TPM reset: the next boot asks for the LUKS password,
and `sudo enroll-tpm` binds the TPM again.

### A new host

Write `modules/hosts/<hostname>/configuration.nix`, starting from an
existing host's, and give the host an age key, in the dev shell:

1. `age-keygen` prints the public key and the secret one.
2. In `secrets/.sops.yaml`, add the public key as `&<hostname>_host`, and a
   creation rule for `<hostname>.yaml` like the others.
3. `sops secrets/<hostname>.yaml` makes its secrets file, with at least
   `luks_password` and the password hashes.
4. `sops secrets/installer.yaml` (with a YubiKey's PIN) takes the secret key
   as `<hostname>_age_key`.

Push, and install it as above: the installer gathers its hardware report
and pushes it.

A new host joins the tailnet once, as Headscale has to approve it (a
reinstalled one gets its place back from the restore):

```sh
sudo tailscale up --login-server=https://vpn.bw20.nl   # any host but dapple
sudo tailscale up --login-server=http://127.0.0.1:8085 # dapple, which runs Headscale
```

It prints a link to a page with a `headscale nodes register` command: run
that on dapple, with the user the device belongs to. dapple itself is then
tagged as a server, which the access policy counts on (`sudo headscale
nodes list` for its ID, then `sudo headscale nodes tag -i <id> -t
tag:server`). A device that needs SSH or the LAN also needs its address in
the policy's `hosts` and grants. dapple has to be at 100.64.0.1, where its
services and DNS records point: Headscale hands out addresses in order, so
if it ever joins as a new device, delete its old one first (`headscale
nodes delete`).

### Restoring data

```sh
sudo offsite-restore              # everything
sudo offsite-restore immich       # or only what's named; --help lists them
```

It downloads first, so a failed download changes nothing. Then it stops the
services, swaps their data in, loads what is backed up as a dump (Immich's
database), and starts them again. If something else still has their data
open, such as Zotero on rocinante, it starts them again and changes
nothing: close it and run it again. What it replaced is kept in
`/persist/.offsite-restore-old-<time>`; to undo, stop the service and move
its folder back. The same command repairs a single service on a running
host, and `--target /tmp/restore-test <entry>` only downloads.

It restores the newest snapshot. Restore before a reinstalled host's first
night, whose backup saves the new, empty folders as the newest; after
that, pick the one from before with `--snapshot <id>`.

Restoring `tailscale` or `headscale` over the tailnet can cut your SSH
session. The restore carries on; reconnect and read
`/var/log/offsite-restore.log`, or watch it over the LAN (`ssh
nixos@192.168.1.162`). A reinstalled dapple needs both restored before the
tailnet works, and a Headscale backup older than a device's registration
logs that device out.

<br/>

## 2 Hosts

| Host | What it is | Runs |
| --- | --- | --- |
| **rocinante** | Framework 13 (13th gen Intel) laptop | Niri with the Weinig shell |
| **dapple** | Home server | Headscale and the services in [section 5](#5-services-on-dapple), backed up to Storj |

Both get the same core: ZFS on LUKS, secure boot, a root that rolls back on
boot, sops secrets, home-manager, and fish.

<br/>

## 3 Safety

- **Disks** are ZFS on LUKS. They unlock with the TPM2, only for a boot
  with secure boot on and our own keys ([Secure boot](#secure-boot)), with
  the LUKS password as the fallback.
- **The root is wiped on every boot**: `zroot/root` rolls back to an empty
  snapshot, and [preservation](https://github.com/nix-community/preservation)
  brings back only the files and folders that are declared, from `/persist`.
  State nobody declared doesn't survive a reboot.
- **Secrets** are in `secrets/<host>.yaml`, one file per host, encrypted
  with sops for that host's own age key, a YubiKey (PIN-protected for the
  server's) and a passphrase fallback. sops-nix decrypts them at
  activation, with the host's own key, into `/run`, never into the Nix
  store. See [Secrets and keys](#8-secrets-and-keys).
- **The server** answers on its tailnet address, with a few things open to
  the internet. A Headscale policy limits what each tailnet device reaches.
  [Network exposure](#6-network-exposure) lists exactly what is reachable
  from where, and [Security](#7-security) who is kept out of what.
- **Deploys** come from Codeberg:
  [comin](https://github.com/nlewo/comin) on each host switches it to the
  tip of `main` if a YubiKey's commit signing key signed it, a minute or
  two after a push plus the build; an unsigned tip deploys nothing, and
  says so only in `sudo comin status`. In this repository jj signs commits
  as they are pushed, with the PIV key on whichever YubiKey is plugged in:
  a touch covers 15 seconds of signing, so a deploy takes a key and a
  touch. A `testing-<host>` branch on top of `main` is switched to with
  `test` instead, which a reboot undoes. Failed builds and deploys show on
  the status page under deploys, and rocinante's desktop says when each
  deploy is done or has failed. If comin can't deploy, `sudo nixos-rebuild
  switch --flake git+https://codeberg.org/BW20/dots#<host>` on the host
  does it by hand. Neither host's Nix trusts a user but root, so the sudo
  password can't be skipped through Nix.
- **Checks**: `nix flake check` builds both hosts and checks formatting and
  lints. `nswitch` refuses to activate uncommitted changes.

<br/>

## 4 Commands

The shell aliases are defined in `modules/features/shell/shell.nix`.

| Command | What it does |
| --- | --- |
| `jj git push` | Deploy: signs what it pushes (YubiKey in, a touch), and every host switches to the tip of `main` (comin); `sudo comin status` shows how far it got |
| `nswitch` | Build and switch to this host's configuration, then restart comin onto it (YubiKey in, no uncommitted changes) |
| `nboot` | The same, from the next boot |
| `ntest` | Switch without making it the boot default (YubiKey in); fine on uncommitted changes |
| `nbuild` | Build only |
| `nrollback` | Go back to the previous generation |
| `nupdate` | Update `flake.lock` |
| `nix fmt` | Format everything (nix-order, nixfmt, deadnix, statix, shfmt, ruff) |
| `nix flake check` | Build every host and run the formatting and lint checks |
| `nix develop` | A shell with sops, age and the YubiKey plugin, set to the plugged-in YubiKey's identity unless `SOPS_AGE_KEY_FILE` already is |
| `nix build .#iso` | The installer ISO, with SSH and `install-host` |
| `nix run .#install -- <host>` | Install a host, from any NixOS live ISO |
| `sudo enroll-tpm` | Re-enroll the TPM2 LUKS keyslot, bound to secure boot (PCR 7), after a firmware update or TPM reset |
| `sudo offsite-restore [--snapshot ID] [entry]` | Restore services' data from the offsite backup ([Restoring data](#restoring-data)) |
| `nix run .#offsite-prune -- <host>` | Prune and check a host's offsite backup, with the Storj owner key from Bitwarden (every few months) |

The programs that rocinante builds with their config in a wrapper
(`wrappers.*`), rather than reading it from `$HOME`, are packages of this
flake too, so they run with that config anywhere. From another machine,
replace `.` with `git+https://codeberg.org/BW20/dots`.

| Command | What runs |
| --- | --- |
| `nix run .#ghostty` | Ghostty, with its settings and both themes; the fonts come from the machine |
| `nix run .#eza` | eza with icons; the colors follow the mode only on rocinante, elsewhere they are eza's own |
| `nix run .#fd` | fd, hidden files included |

<br/>

## 5 Services on dapple

Each service is at `<subdomain>.bw20.nl`, with one wildcard certificate for
all of them.

| Service | Subdomain | What for |
| --- | --- | --- |
| Headscale | `vpn` | The tailnet's control server, with an embedded DERP relay |
| Immich | `photos` | Photos |
| Jellyfin | `media` | Films, series and music |
| Sonarr, Radarr, Lidarr | `series`, `movies`, `music` | Fetching media for Jellyfin |
| Prowlarr, Bazarr, qBittorrent | `prowlarr`, `bazarr`, `torrents` | Indexers, subtitles, downloads |
| slskd | `soulseek` | Soulseek downloads, which Soularr hands to Lidarr |
| Vaultwarden | `passwords` | Passwords |
| Calibre-Web | `books` | E-books, synced to a Kobo |
| Radicale | `contacts` | Contacts and calendars |
| File Browser | `files` | rocinante's synced `~/Documents`, in the browser |
| Home Assistant | `home` | IoT in the home |
| New Leaf | `cv` | CV editor, with public share links |
| meetinn | `inn` | ICT Netwerk Nijmegen's site, public; a demo until it has its own server |
| Blog | bare domain | My blog, public; dapple builds it from every push to its repository |
| Jeltje's blog | `jeltje` | Jeltje's blog, public, built the same way from its own repository |
| PubHubs preview | `pubhubs` | The new PubHubs website, public; temporary, and copied over by hand |
| Gatus | `status` | Monitoring of all of the above |
| ntfy | `alerts` | Gatus's alerts, to the phone's ntfy app and rocinante's desktop |

Syncthing keeps dapple's copy of rocinante's `~/Documents`, over the
tailnet only, without a web page of its own.

A Forgejo runner takes CI jobs from Codeberg for my own repositories (it is
registered with my account), with KVM for NixOS VM tests, also without a
web page; it reaches the internet only ([Security](#7-security)).

Backups: the services' data to Storj with restic, daily, with credentials
that can't delete or overwrite (pruning is by hand, from rocinante). Each
run reports to Gatus; a failed one alerts at once and is tried again 5
minutes later, on a fresh snapshot, up to 12 times a night. With them goes
a copy of every flake input, so the hosts can be built without the forges
they come from (`flake-archive.nix` has how). Locally, sanoid keeps hourly
to yearly ZFS snapshots of `/persist`. Every host reports its disks' and
pools' health to Gatus too (smartd and `zpool status`, hourly), and its
failed units, and the blogs their deploys. Whatever Gatus sees go down, or
come back, goes to the phone through ntfy, and to rocinante's desktop as a
notification.

<br/>

## 6 Network exposure

**From the internet**, the router forwards 443/tcp and 3478/udp to dapple.
There, six things are served, at names that point straight at the home
address (DNS at deSEC, no proxy, so TLS ends on dapple):

- **Headscale** at `vpn`: the control protocol, the DERP relay and its STUN,
  which a device away from home needs to join the tailnet. Its admin API
  (`/api`, `/swagger`) only answers tailnet addresses: the `headscale` CLI
  uses a local socket.
- **New Leaf's share links** at `cv`: static pages and PDFs at random
  addresses. The editor is not reachable from the internet.
- **meetinn** at `inn`: ICT Netwerk Nijmegen's events, registration and
  Yivi tickets, the admin included (its login is a Yivi email disclosure).
- **The blog** at the bare domain: static pages, with a 403 for the AI
  crawlers its robots.txt names, and `/micropub`, where posts come in, with
  a token and a rate limit.
- **Jeltje's blog** at `jeltje`: the same, from its own repository.
- **The PubHubs preview** at `pubhubs`: static pages, marked noindex.

`kobo` answers too, but with a 403 on `/kobo/`, as its sync API is for the
LAN subnet only, and a 404 on anything else. A name no vhost claims gets no
certificate and no answer.

**From the tailnet**, every service in [section 5](#5-services-on-dapple)
but Headscale, meetinn, the blogs and the PubHubs preview, over HTTPS on
dapple's tailnet address. Those five answer only at the public address,
like any visitor's. SSH, Syncthing (22000/tcp) and the home LAN (through
dapple's subnet route) only from the devices the
[access policy](modules/features/services/headscale/headscale-policy.hujson)
names: rocinante, and two phones for the LAN. The services' vhosts are
bound to that address and refuse any source outside the tailnet; the
firewall (nftables) opens only 443, 22 and 22000 on it.

**From the LAN** (`enp2s0`), besides the internet's ports:

- SSH on 22, from the LAN subnet only.
- `kobo.bw20.nl` on 443, the Kobo sync API only (`/kobo/`), allowed for the
  LAN subnet only.

Not Jellyfin's or Home Assistant's plain-HTTP ports: clients use HTTPS over
the tailnet. SSH is public key only, for the `nixos` user, with keys from
this repository only (not `~/.ssh`). Tailscale's WireGuard is on 41641/udp
on every interface.

**rocinante** opens no ports but Tailscale's 41641/udp, and 5353/udp for
mDNS, to find the installer ISO.

**Outgoing**: restic to Storj, ACME certificates through deSEC's DNS, and
the status page's checks of the public sites, at the public address
through the router's hairpin NAT, the blogs' polling of Codeberg and their
receivers' pushes to it, and meetinn's hourly update of its Yivi schemes
and its mail, through Proton's SMTP. The Forgejo runner polls Codeberg for
jobs, which fetch what they build from the internet (and nothing on the
LAN or the tailnet). Besides those, the apps fetch what they're for, from
the home address: qBittorrent's torrents and slskd's Soulseek downloads (no
VPN), Prowlarr's indexers (through FlareSolverr where Cloudflare guards
one), metadata and subtitles for the *arr apps, Bazarr and Jellyfin,
Recyclarr's quality profiles from GitHub, Vaultwarden's site icons, and
Immich's machine-learning models on first use.

<br/>

## 7 Security

Who is kept out of what, beyond the ports in
[Network exposure](#6-network-exposure):

- **A tailnet device** gets what the policy grants: every device the
  services on dapple; a person's own devices each other; rocinante SSH
  and Syncthing on dapple; two phones the home LAN, for the camera.
  dapple is `tag:server`, so it isn't anyone's own device, and the build
  checks the policy's addresses against `lib.site`. The apps ask for
  their own login, except Gatus's read-only status page and New Leaf's
  editor, which goes by your tailnet user.
- **A process on dapple**, such as a compromised service, can't decrypt
  (the age key is root's alone), can't read other services' secrets or
  state (each readable by its own service only, and kept off command
  lines), can't become root through Nix, and can't plant a lasting
  SSH key.
- **A CI job** runs on dapple as the runner's dynamic user, cut off from
  localhost, the LAN and the tailnet (`IPAddressDeny`), with no `/home`,
  building through the Nix daemon as an allowed, not a trusted, user.
- **Someone with the Codeberg login** can't deploy: comin only switches to
  a commit signed by a key in `lib.commitSigners`, a PIV key on a YubiKey.
  Nor can code running as `jorrit` on rocinante without a YubiKey in and a
  touch. They can hold updates back, but not roll a host back: comin
  refuses a `main` that isn't on top of the one it saw last.
- **A machine posing as dapple** is refused: rocinante pins dapple's host
  key.
- **One host taken over** doesn't give up the other's secrets, LUKS, root
  or restic passwords, and rocinante takes no packages from dapple.
  Editing dapple's secrets needs a YubiKey's PIN and a touch, so a stolen
  laptop with a key in doesn't open the server.
- **Ransomware on a host** can't take the offsite backups along: its Storj
  credentials reach only its own folder and can't delete, which on Storj
  also means they can't overwrite (tested on the real bucket).
- **A thief** gets encrypted disks, and no boot menu editor. rocinante's
  disk also opens with either YubiKey's FIDO2 slot, which needs the key's
  PIN and a touch, so the laptop and a key together still aren't enough.

**Checked by hand** on 2026-10-10, and the router, the deSEC token and the
403s from outside again on 2026-10-16. Check again after changing the
router, the DNS or an app's own settings:

- The router forwards only 443/tcp and 3478/udp to dapple, and passes
  internet visitors' own addresses on: from mobile data,
  `curl --resolve kobo.bw20.nl:443:<home-ip> https://kobo.bw20.nl/kobo/x`
  answers 403, and so does `https://vpn.bw20.nl/api/v1/node`.
- Vaultwarden's `ADMIN_TOKEN` is an argon2 hash, Calibre-Web's admin
  password isn't the default, and qBittorrent's password is long and
  random.
- The deSEC token can only write the `_acme-challenge` TXT record, and only
  from the home address. It can still read the whole zone, as every deSEC
  token can.
- Jellyfin's Known Proxies has 127.0.0.1, so it sees the real client
  address.
- Neither YubiKey's PUK is the factory default, or anyone holding it could
  set a new PIN.

**Accepted on purpose:**

- **The TPM doesn't check which disk it unlocks.** Its slot is bound to PCR
  7 alone, so someone with the machine could put in a volume of their own
  under the same name, type its password, and boot their own `init`, which
  the TPM then unseals the real disk's key for. Not tested; it takes time
  alone with the machine. The fix is a check of PCR 15 in the initrd.
- **A CI workflow runs code on dapple**: whoever can start one in a
  repository of an owner the runner serves (`my.forgejo-runner.connections`:
  their committers, and a fork's pull request unless Codeberg holds those
  for approval) runs it as the runner's user, with the internet. Enough to
  send spam or fill the disk with Nix builds; not enough to reach the
  services, the LAN or the tailnet, or to become root.
- **A signed push is a deploy, as root, on every host, and a touch covers
  15 seconds of signing**, so code running as `jorrit` that signs right
  after one of your pushes deploys with it. Someone with the Codeberg login
  alone can point `main` at any other signed commit of yours on top of
  what's deployed.
- **The installer can push to `main`**, with the deploy key in
  `secrets/installer.yaml`, so a YubiKey with its PIN, or the passphrase,
  is a way to push, unsigned, though only to this repository. That deploys
  nothing until a signed commit lands on top. For it, `main` takes unsigned
  pushes, so your Codeberg login can make them too, which at most holds
  deploys back.
- **comin fetches from Codeberg as root** every minute, and parses what it
  gets before checking any signature.
- **Headscale listens on 127.0.0.1:8085**, and Vaultwarden on 8222, ports a
  local process could take while they restart.
- **The installer ISO runs the installer from Codeberg's `main`**, so it
  installs whatever was pushed last.
- **Certificate Transparency logs list the services' names**, from before
  the wildcard certificate, and **Headscale's `/version` is public**.
- **qBittorrent's password hash is in the repository**, which is fine with
  a long, random password.
- **ntfy's state directory is 0777**, inside `/var/lib/private`, which
  systemd keeps at 0700.
- **rocinante's keyring has an empty password**, as the session logs in
  automatically; LUKS protects it on disk.

**Checking it**, from rocinante and on dapple:

```sh
curl -m5 http://100.64.0.1:6767/                 # times out: only 443, 22 and 22000 on the tailnet
curl -sk -m5 https://100.64.0.1/ -H 'Host: x'    # refused: unknown name
ssh nixos@dapple nix store info                  # Trusted: 0
sudo headscale nodes list                        # on dapple: dapple has tag:server
systemctl --failed                               # on dapple: nothing
```

`nix flake check` scores every long-running service that runs as its own
user with `systemd-analyze security`: at most 2.0 of 10, or the ceiling
`checks.nix` names with its reason.

<br/>

## 8 Secrets and keys

Each host has its own file, `secrets/<host>.yaml`, and decrypts only that
one, at activation, with its own age key in
`/persist/system/var/lib/sops/age.key`, root's alone. No host needs a
YubiKey to boot. Two YubiKeys open the same, so losing one loses nothing,
and a passphrase identity in Bitwarden is the fallback. `secrets/.sops.yaml`
has the recipients, and why each.
`secrets/installer.yaml` holds what the installer needs besides: each host's
age key and the Codeberg deploy key. Only the YubiKeys' PIN identities and
the passphrase open it, no host.

Edit a secret in the dev shell (`nix develop`), with a YubiKey in:

```sh
sops secrets/rocinante.yaml
sops secrets/dapple.yaml        # asks for the YubiKey's PIN, then a touch
```

Without a YubiKey, point `SOPS_AGE_KEY_FILE` at the passphrase identity,
saved to a file from Bitwarden, before `nix develop`, `install` or
`offsite-prune`; they keep it when it is set. What a secret has to look
like is on the code that reads it (`lib.mkUser` for the password hashes,
`ssh-server.nix` for the SSH host key, `bazarr.nix`).

### Enrolling a YubiKey

A new key, or one replacing a lost one, gets what the others have. First
its PIV PIN, PUK and management key, none the factory default (`ykman piv
info` warns about any that is). Then its two age identities, its FIDO2 PIN
and slot on rocinante's disk (with only this key plugged in; it shows up
twice, so name its `/dev/hidraw*` path from the list), and its commit
signing key:

```sh
age-plugin-yubikey --generate --pin-policy never --touch-policy never
age-plugin-yubikey --generate --pin-policy once --touch-policy cached

systemd-cryptenroll --fido2-device=list
sudo systemd-cryptenroll --fido2-device=/dev/hidrawN --fido2-with-client-pin=yes \
  --fido2-with-user-presence=yes /dev/disk/by-partlabel/disk-main-luks

pkill -HUP yubikey-agent   # it keeps the PIV applet to itself
ykman piv keys generate --algorithm ECCP256 --pin-policy NEVER --touch-policy CACHED \
  9a ~/.ssh/commit-signing-piv-<serial>.pem
ykman piv certificates generate --valid-days 36500 \
  --subject "CN=commit signing YubiKey <serial>" 9a ~/.ssh/commit-signing-piv-<serial>.pem
```

Then add the no-PIN `age1yubikey1...` recipient to rocinante's list in
`secrets/.sops.yaml` and the PIN one to dapple's and the installer's,
`sops updatekeys` the three files, and add the signing key's SSH form
(`ssh-keygen -i -m PKCS8 -f <pem>`) to `lib.commitSigners` as
`jorrit+git@bw20.nl <key>`. The hosts check against the list they run, so
sign that commit with a key already on it. Push, then check with only the new key plugged in:
`sops -d --extract '["restic_password"]' secrets/rocinante.yaml >/dev/null`.

### Revoking a key

1. Remove its recipient from `secrets/.sops.yaml`, and a YubiKey's signing
   key from `lib.commitSigners`. Sign with the other YubiKey: until the
   hosts run that commit, they still deploy what the lost one signs.
2. `sops updatekeys`, then `sops rotate -i`, every file it was a recipient
   of: `updatekeys` alone keeps the data key, which the lost key still
   unwraps from old copies, such as the repository's history.
3. Change the secrets themselves, as the old copies still open: the LUKS
   password (`cryptsetup luksChangeKey` on every disk, then `sudo
   enroll-tpm`), the restic password (`restic key add`, then `restic key
   remove` the old one, with the owner's S3 key), the Storj credentials
   (`offsite-backup.nix`), the password hashes, dapple's SSH host key, and
   the tokens and API keys. For a YubiKey or the passphrase, also every
   host's age key ([A host's age key](#a-hosts-age-key)) and the Codeberg
   deploy key, which `secrets/installer.yaml` holds.
4. Push, and deploy every host.

### A host's age key

A host keeps its age key across installs: the installer takes it from
`secrets/installer.yaml`. To replace it, after a theft or a revoked
YubiKey, make one with `age-keygen`, put its public key in place of
`<host>_host` in `secrets/.sops.yaml`, `sops updatekeys` and `sops rotate
-i` the host's file, and put the secret key in place of `<host>_age_key`
with `sops secrets/installer.yaml`. A host about to be installed gets it
from the installer. On a running one, add it to
`/persist/system/var/lib/sops/age.key` next to the old one before you push,
so a reboot before the deploy still decrypts, and remove the old one's
lines once deployed.

<br/>

## 9 Recovery

Nothing needed to recover lives only on rocinante: the SSH keys and the
passphrase identity are in Bitwarden, the configuration is on Codeberg,
the data on Storj, and the YubiKeys are separate devices.

- **rocinante.** Boot the ISO on its replacement and run `install-host
  rocinante` on its console, which gathers and pushes its hardware report,
  then follow [First boot](#first-boot). Only what rocinante's backup holds
  comes back: Zotero, the Obsidian vault, and its place on the tailnet.
- **A stolen rocinante.** Its disk unlocks with the TPM for whoever boots
  it, into a locked session, so count its secrets, tailnet node and Storj
  credentials as known. Install its replacement as above, but:
  1. Before installing, give it a new age key
     ([A host's age key](#a-hosts-age-key)) and push, and delete its node
     on dapple (`sudo headscale nodes list`, then `sudo headscale nodes
     delete -i <id>`). Restore with `sudo offsite-restore other`, not
     `tailscale`, which would bring back the stolen node's key, and join as
     a new host. Put its new address in
     place of `100.64.0.2` in the access policy, `lib.site` and the
     browser's `policies.nix`.
  2. Rotate its secrets, as in [Revoking a key](#revoking-a-key) from step
     2. Its `gatus_push_token` and `ntfy_token` are also in
     `secrets/dapple.yaml`, as `gatus_push_token_rocinante` and
     `ntfy_token_rocinante`: change both copies.
  3. Revoke its Storj credentials and make new ones (`offsite-backup.nix`).
- **A YubiKey.** [Revoke it](#revoking-a-key) and
  [enroll a new one](#enrolling-a-yubikey), with the other key or the
  passphrase identity.
- **Both machines.** Bitwarden then only has the offline copy on your
  phone, as Vaultwarden runs on dapple. With a YubiKey left, install dapple
  and run `sudo offsite-restore`, which brings
  Vaultwarden back, and rocinante can follow. With none left, enroll a new
  one first, with the passphrase identity: on the ISO, `nix shell
  nixpkgs#sops nixpkgs#age-plugin-yubikey` has the tools.

That last case depends on your phone. An offline copy of the passphrase
identity and your Bitwarden recovery details, kept somewhere safe, removes
that dependency.

A forge or repository that's gone: dapple keeps a copy of every flake
input, and `flake-archive.nix` has the steps to build from it.

<br/>

## 10 Layout

[import-tree](https://github.com/vic/import-tree) imports every `.nix` file
under `modules/` as a [flake-parts](https://flake.parts) module, so a new
file needs no listing, only `jj` to have seen it.

```
modules/
  features/<area>/<feature>.nix   one NixOS module each: flake.nixosModules.<feature>
  features/<area>/<feature>/      a feature too big for one file, and the files it reads
  bundles/                        base (every host) and desktop (a host with a screen)
  hosts/<host>/                   flake.nixosConfigurations.<host>, facter.json, hardware.nix
  users/<user>/                   flake.nixosModules.<user>, made with lib.mkUser
  flake/                          checks, formatter, dev shell, wrappers, lib, site, installer ISO
scripts/                          install, install-vm, enroll-tpm, offsite-prune, nix-order
secrets/                          <host>.yaml, and .sops.yaml with the recipients
```

A feature is on when the host imports it, and keeps its settings under
`my.<feature>`. One that needs another asserts it is imported. Desktop and
app features configure the user through `home-manager.sharedModules`. A
service declares its state in `my.preservation` and `my.offsite-backup`, its
page in `my.ingress`, and its unit gets `lib.restartAlways` and, where
nixpkgs gives none, `lib.sandbox`: `contacts.nix` is the smallest complete
one, with the steps for a new one. Shared helpers and facts are in
`modules/flake/lib.nix` and `site.nix`.

The installer, its rehearsal VM (`nix run .#install-vm`, whose header has
the steps) and the ISO read the repository, the paths in it and the
secrets' names from each host's `yubinstall` options (`yubinstall.nix`),
which the base bundle sets, so they can move to a repository of their own.

`nix fmt` orders attributes before nixfmt lays them out (the rules are in
`scripts/nix-order.py`), and the comment rules are in `checks.nix`.
`nix flake check` builds every host and the install scripts (with
shellcheck), runs the formatters and linters, statix's lints, the comment
grep, and the hardening scores.
