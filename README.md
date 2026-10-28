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

## Table of contents

- [1 Installation](#1-installation)
- [2 Hosts](#2-hosts)
- [3 Safety](#3-safety)
- [4 Documentation](#4-documentation)
- [5 Commands](#5-commands)
- [6 Services on dapple](#6-services-on-dapple)
- [7 Network exposure](#7-network-exposure)

<br/>

## 1 Installation

Write the installer ISO (`nix build .#iso`) to a USB stick and boot the
target machine from it, with network and a YubiKey plugged in. Then, from
any computer with your SSH key (it's in Bitwarden), or on its own console:

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

It shows the disk it is about to wipe and waits for a `yes`, installs the
host, and clones this repository to `/etc/nixos`. Reboot and type the LUKS
password until
[secure boot](docs/install.md#secure-boot) is on: its first boot binds the
TPM, so later boots unlock by themselves. Then `sudo offsite-restore` brings
back its data, and with it its place on the tailnet. A new host
[joins the tailnet](docs/install.md#joining-the-tailnet) once instead.

[Installing a host](docs/install.md) has the details, the steps for a new
host, and what to do after losing a machine.

<br/>

## 2 Hosts

| Host | What it is | Runs |
| --- | --- | --- |
| **rocinante** | Framework 13 (13th gen Intel) laptop | Niri with the Noctalia shell, colors from the wallpaper, Zen, Zed, Zotero and Obsidian |
| **dapple** | Home server | Headscale and the services in [section 6](#6-services-on-dapple), backed up to Storj |

Both get the same core: ZFS on LUKS, secure boot, a root that rolls back on
boot, sops secrets, home-manager, and fish.

<br/>

## 3 Safety

- **Disks** are ZFS on LUKS. They unlock with the TPM2, only for a boot
  with secure boot on and our own keys
  ([lanzaboote](docs/install.md#secure-boot)), with the LUKS password as
  the fallback.
- **The root is wiped on every boot**: `zroot/root` rolls back to an empty
  snapshot, and [preservation](https://github.com/nix-community/preservation)
  brings back only the files and folders that are declared, from `/persist`.
  State nobody declared doesn't survive a reboot.
- **Secrets** are in `secrets/<host>.yaml`, one file per host, encrypted
  with sops for that host's own age key, a YubiKey (PIN-protected for the
  server's) and a passphrase fallback. sops-nix decrypts them at
  activation, with the host's own key, into `/run`, never into the Nix
  store. See [Secrets and keys](docs/secrets.md).
- **The server** answers on its tailnet address, with a few things open to
  the internet. A Headscale policy limits what each tailnet device reaches.
  [Section 7](#7-network-exposure) lists exactly what is reachable from
  where, and [Security](docs/security.md) who is kept out of what.
- **Deploys** come from Codeberg:
  [comin](https://github.com/nlewo/comin) on each host switches it to the
  newest commit on `main` signed by a YubiKey's commit signing key, within
  a minute or two of a push. In this repository jj signs commits as they
  are pushed, with the PIV key on whichever YubiKey is plugged in: a touch
  covers 15 seconds of signing, so a deploy takes a key and a touch. A
  `testing-<host>` branch on top of `main` is switched to with `test`
  instead, which a reboot undoes. Failed builds and deploys show on the
  status page under deploys, and rocinante's desktop says when each deploy
  is done or has failed. If comin
  can't deploy, `sudo nixos-rebuild switch --flake
  git+https://codeberg.org/BW20/dots#<host>` on the host does it by hand.
  dapple's Nix trusts no user but root, so the sudo password can't be
  skipped through Nix.
- **Checks**: `nix flake check` builds both hosts and checks formatting and
  lints. `nswitch` refuses to activate uncommitted changes.

<br/>

## 4 Documentation

- [**Installing a host**](docs/install.md) - The ISO and the installer,
  joining the tailnet, restoring data, new hosts, and losing a machine or
  an upstream.
- [**Secrets and keys**](docs/secrets.md) - The per-host files and their
  keys, changing a secret, adding or revoking a key, and the passphrase
  fallback.
- [**Security**](docs/security.md) - Who is kept out of what, what was
  checked by hand, what is accepted on purpose, and how to check it.
- [**Layout**](docs/layout.md) - How the modules are found, what a feature is,
  the shared helpers, and the rules for ordering, comments and checks.

<br/>

## 5 Commands

The shell aliases are defined in `modules/features/shell/shell.nix`.

| Command | What it does |
| --- | --- |
| `jj git push` | Deploy: signs what it pushes (YubiKey in, a touch), and every host switches to the tip of `main` (comin); `sudo comin status` shows how far it got |
| `nswitch` | Build and switch to this host's configuration, then restart comin onto it (YubiKey in, no uncommitted changes) |
| `nboot` | The same, from the next boot |
| `ntest` | Switch without making it the boot default; fine on uncommitted changes |
| `nbuild` | Build only |
| `nrollback` | Go back to the previous generation |
| `nupdate` | Update `flake.lock` |
| `nix fmt` | Format everything (nix-order, nixfmt, deadnix, statix, shfmt, ruff) |
| `nix flake check` | Build every host and run the formatting and lint checks |
| `nix develop` | A shell with sops, age and the YubiKey plugin, set to the plugged-in YubiKey's identity unless `SOPS_AGE_KEY_FILE` already is |
| `nix build .#iso` | The installer ISO, with SSH and `install-host` |
| `nix run .#install -- <host>` | Install a host, from any NixOS live ISO |
| `sudo enroll-tpm` | Re-enroll the TPM2 LUKS keyslot, bound to secure boot (PCR 7), after a firmware update or TPM reset |
| `sudo offsite-restore [--snapshot ID] [entry]` | Restore services' data from the offsite backup ([details](docs/install.md#restoring-data)) |
| `nix run .#offsite-prune -- <host>` | Prune and check a host's offsite backup, with the Storj owner key from Bitwarden (every few months) |

<br/>

## 6 Services on dapple

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
| Gatus | `status` | Monitoring of all of the above |
| ntfy | `alerts` | Gatus's alerts, to the phone's ntfy app and rocinante's desktop |

Syncthing keeps dapple's copy of rocinante's `~/Documents`, over the
tailnet only, without a web page of its own.

A Forgejo runner takes CI jobs from Codeberg for my own repositories (it is
registered with my account), with KVM for NixOS VM tests, also without a
web page; it reaches the internet only
([Security](docs/security.md#who-is-kept-out-of-what)).

Backups: the services' data to Storj with restic, daily, with credentials
that can't delete or overwrite (pruning is by hand, from rocinante). Each
run reports to Gatus; a failed one alerts at once and is tried again 5
minutes later, on a fresh snapshot, up to 12 times a night. With them goes
a copy of every flake input, so the hosts can be built without the forges
they come from ([Losing an upstream](docs/install.md#losing-an-upstream)).
Locally, sanoid keeps hourly to yearly ZFS snapshots of `/persist`. Every
host reports its disks' and pools' health to Gatus too
(smartd and `zpool status`, hourly), and the blogs their deploys. Whatever
Gatus sees go down, or come back, goes to the phone through ntfy, and to
rocinante's desktop as a notification.

<br/>

## 7 Network exposure

**From the internet**, the router forwards 443/tcp and 3478/udp to dapple.
There, five things are served, at names that point straight at the home
address (DNS at deSEC, no proxy):

- **Headscale** at `vpn`: the control protocol, the DERP relay and its STUN,
  which a device away from home needs to join the tailnet. Its admin API
  (`/api`, `/swagger`) only answers tailnet addresses: the `headscale` CLI
  uses a local socket.
- **New Leaf's share links** at `cv`: static pages and PDFs at random
  addresses. The editor is not reachable from the internet.
- **meetinn** at `inn`: ICT Netwerk Nijmegen's events, registration and
  Yivi tickets, the admin included (its login is a Yivi email disclosure).
- **The blog** at the bare domain: static pages, with a 403 for the AI
  crawlers its robots.txt names.
- **Jeltje's blog** at `jeltje`: the same, from its own repository.

`kobo` answers too, but with a 403: its sync API is for the LAN subnet
only. A name no vhost claims gets no certificate and no answer.

**From the tailnet**, every service in [section 6](#6-services-on-dapple)
but meetinn and the blogs, over HTTPS on dapple's tailnet address. Those
three answer only at the public address, like any visitor's. SSH, Syncthing
(22000/tcp) and the home LAN (through dapple's subnet route) only from the
devices the
[access policy](modules/features/services/headscale/headscale-policy.hujson) names:
rocinante, and two phones for the LAN. The services' vhosts are bound to
that address and refuse any source outside the tailnet; the firewall
(nftables) opens only 443, 22 and 22000 on it. [Security](docs/security.md)
says why.

**From the LAN** (`enp2s0`), besides the internet's ports:

- SSH on 22, from the LAN subnet only.
- `kobo.bw20.nl` on 443, the Kobo sync API only (`/kobo/`), allowed for the
  LAN subnet only.

SSH is public key only, for the `nixos` user, with keys from this repository
only (not `~/.ssh`). Tailscale's WireGuard is on 41641/udp on every
interface.

**rocinante** opens no ports but Tailscale's 41641/udp, and 5353/udp for
mDNS, to find the installer ISO.

**Outgoing**: restic to Storj, ACME certificates through deSEC's DNS, and
the status page's checks of the public sites but Headscale, at the public
address through the router's hairpin NAT, and meetinn's hourly
update of its Yivi schemes and its mail, through Proton's SMTP. The
Forgejo runner polls Codeberg for jobs, which fetch what they build from
the internet (and nothing on the LAN or the tailnet). Besides
those, the apps fetch what they're for, from the home address: qBittorrent's
torrents and slskd's Soulseek downloads (no VPN), Prowlarr's indexers
(through FlareSolverr where Cloudflare guards one), metadata and subtitles
for the *arr apps, Bazarr and Jellyfin, Recyclarr's quality profiles from
GitHub, Vaultwarden's site icons, and Immich's machine-learning models on
first use.
