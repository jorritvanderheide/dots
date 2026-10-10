# <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="48" align="absmiddle" /> Dots

**Jorrit's NixOS configuration: a laptop to work on, and a server for the home.**

One flake for two machines. rocinante is a Framework laptop with a niri
desktop; dapple is the home server, with photos, media, passwords and a
self-hosted tailnet. Both wipe their root on every boot and keep only what is
declared, their disks unlock with the TPM, and their secrets are in this
repository, encrypted for a YubiKey. See [Installation](#1-installation).

<br/>

![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-5277c3?style=flat-square&logo=nixos&logoColor=white)
![Hosts: rocinante and dapple](https://img.shields.io/badge/hosts-rocinante%20%7C%20dapple-5277c3?style=flat-square)
![flake-parts and import-tree](https://img.shields.io/badge/built%20with-flake--parts%20%2B%20import--tree-5277c3?style=flat-square)

<br/>

## 1 Installation

Write the installer ISO (`nix build .#iso`) to a USB stick and boot the
target machine from it, with network and a YubiKey plugged in. Then, from
any computer with your SSH key (it's in Bitwarden), or on its own console:

```sh
ssh -t root@dots-installer.local install-host <hostname>
```

It shows the disk it is about to wipe and waits for a `yes`, installs the
host, and clones this repository to `/etc/nixos`. Reboot with the YubiKey
still in and type the LUKS password until
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
| **rocinante** | Framework 13 (13th gen Intel) laptop | Niri with the Noctalia shell, Stylix theming, Zen, Zed, Zotero and Obsidian |
| **dapple** | Home server | Headscale and the services in [section 6](#6-services-on-dapple), backed up to Storj |

Both get the same core: ZFS on LUKS, a root that rolls back on boot, sops
secrets, home-manager, and fish.

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
  with sops for that host's key (rocinante's YubiKey, dapple's own age key),
  a PIN-protected admin key and a passphrase fallback. They are decrypted at
  boot by the service that needs them, never written to the Nix store. See
  [Secrets and keys](docs/secrets.md).
- **The server** answers on its tailnet address, with only Headscale and New
  Leaf's share links open to the internet. A Headscale policy limits what
  each tailnet device reaches. [Section 7](#7-network-exposure) lists
  exactly what is reachable from where, and [Security](docs/security.md) who
  is kept out of what.
- **Deploys** to dapple are signed by rocinante, and dapple's Nix trusts no
  user but root, so the sudo password can't be skipped through Nix.
- **Checks**: `nix flake check` builds both hosts and checks formatting and
  lints. `nswitch` refuses to activate uncommitted changes.

<br/>

## Table of contents

- [4 Documentation](#4-documentation)
- [5 Commands](#5-commands)
- [6 Services on dapple](#6-services-on-dapple)
- [7 Network exposure](#7-network-exposure)

<br/>

## 4 Documentation

- [**Installing a host**](docs/install.md) - The ISO and the installer, why
  accounts start locked, joining the tailnet, restoring data, new hosts, and
  losing a machine.
- [**Secrets and keys**](docs/secrets.md) - The per-host files and their
  keys, changing a secret, adding or revoking a key, and the passphrase
  fallback.
- [**Security**](docs/security.md) - Who is kept out of what, what was
  checked by hand, what is accepted on purpose, and how to check it.
- [**Layout**](docs/layout.md) - How the modules are found, what a feature is,
  and the shared helpers.

<br/>

## 5 Commands

The shell aliases are defined in `modules/features/shell/shell.nix`.

| Command | What it does |
| --- | --- |
| `nswitch` | Build and switch to this host's configuration (YubiKey in, no uncommitted changes) |
| `nboot` | The same, from the next boot |
| `ntest` | Switch without making it the boot default; fine on uncommitted changes |
| `nbuild` | Build only |
| `ndeploy <host> [switch\|boot]` | Build here, signed with rocinante's deploy key, and activate on another host over SSH |
| `nrollback` | Go back to the previous generation |
| `nupdate` | Update `flake.lock` |
| `nix fmt` | Format everything (nixfmt, deadnix, statix, shfmt, ruff) |
| `nix flake check` | Build every host and run the formatting and lint checks |
| `nix develop` | A shell with sops, age and the YubiKey plugin |
| `nix build .#iso` | The installer ISO, with SSH and `install-host` |
| `nix run .#install -- <host>` | Install a host, from any NixOS live ISO |
| `sudo enroll-tpm` | Re-enroll the TPM2 LUKS keyslot, bound to secure boot (PCR 7), after a firmware update or TPM reset |
| `sudo offsite-restore [entry]` | Restore services' data from the offsite backup ([details](docs/install.md#restoring-data)) |
| `nix run .#offsite-prune -- <host>` | Prune and check a host's offsite backup, with the Storj owner key from Bitwarden (every few months) |

<br/>

## 6 Services on dapple

Each service is at `<subdomain>.bw20.nl`, with its own certificate.

| Service | Subdomain | What for |
| --- | --- | --- |
| Headscale | `vpn` | The tailnet's control server, with an embedded DERP relay |
| Immich | `photos` | Photos |
| Jellyfin | `media` | Films, series and music |
| Sonarr, Radarr, Lidarr | `series`, `movies`, `music` | Fetching media for Jellyfin |
| Prowlarr, Bazarr, qBittorrent | `prowlarr`, `bazarr`, `torrents` | Indexers, subtitles, downloads |
| Vaultwarden | `passwords` | Passwords |
| Calibre-Web | `books` | E-books, synced to a Kobo |
| Radicale | `contacts` | Contacts and calendars |
| Home Assistant | `home` | IoT in the home |
| New Leaf | `cv` | CV editor, with public share links |
| Gatus | `status` | Monitoring of all of the above |

Backups: the services' data to Storj with restic, daily, with credentials
that can't delete or overwrite (pruning is by hand, from rocinante),
reported to Gatus. Locally, sanoid keeps hourly to yearly ZFS snapshots of
`/persist`.

<br/>

## 7 Network exposure

**From the internet**, the router forwards 443/tcp and 3478/udp to dapple.
There, only two things answer:

- **Headscale** at `vpn`: the control protocol and the DERP relay, which a
  device away from home needs to join the tailnet. Its admin API
  (`/api`, `/swagger`) is refused unless the request comes from the tailnet.
- **New Leaf's share links** at `cv`: static pages and PDFs at random
  addresses. The editor is not reachable from the internet.

A name no vhost claims gets no certificate and no answer.

**From the tailnet**, every service in [section 6](#6-services-on-dapple),
over HTTPS on dapple's tailnet address. SSH and the home LAN (through
dapple's subnet route) only from the devices the
[access policy](modules/features/services/headscale-policy.hujson) names:
rocinante, and two phones for the LAN. The services' vhosts are bound to
that address and refuse any source outside the tailnet, so they answer
neither on the public address nor to a LAN device that routes the tailnet
address through dapple. The firewall is nftables, so its tailnet rules hold
even though tailscaled accepts all tailnet traffic in its own table.

**From the LAN** (`enp2s0`), besides the internet's ports:

- SSH on 22, from the LAN subnet only.
- `kobo.bw20.nl` on 443, the Kobo sync API only (`/kobo/`), allowed for the
  LAN subnet only.

SSH is public key only, for the `nixos` user, with keys from this repository
only (not `~/.ssh`). Tailscale's WireGuard is on 41641/udp on every
interface.

**rocinante** opens no ports but Tailscale's 41641/udp, and 5353/udp for
mDNS, to find the installer ISO.

**Outgoing**: restic to Storj, and ACME certificates through Cloudflare DNS.
