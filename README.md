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
still in and type the LUKS password once: that boot enrolls the TPM, so
later boots unlock by themselves. Then `sudo offsite-restore` brings back its
data, and with it its place on the tailnet. A new host
[joins the tailnet](docs/install.md#joining-the-tailnet) once instead.

[Installing a host](docs/install.md) has the details, the steps for a new
host, and what to do after losing a machine.

<br/>

## 2 Hosts

| Host | What it is | Runs |
| --- | --- | --- |
| **rocinante** | Framework 13 (13th gen Intel) laptop | Niri with the Noctalia shell, Stylix theming, Zen, Zed, Zotero and Obsidian |
| **dapple** | Home server | Headscale and the services in [section 6](#6-services-on-dapple), backed up to USB and to Storj |

Both get the same core: ZFS on LUKS, a root that rolls back on boot, sops
secrets, home-manager, and fish.

<br/>

## 3 Safety

- **Disks** are ZFS on LUKS. They unlock with the TPM2, with the LUKS
  password as the fallback.
- **The root is wiped on every boot**: `zroot/root` rolls back to an empty
  snapshot, and [preservation](https://github.com/nix-community/preservation)
  brings back only the files and folders that are declared, from `/persist`.
  State nobody declared doesn't survive a reboot.
- **Secrets** are in `secrets/secrets.yaml`, encrypted with sops for each
  host's YubiKey and a passphrase fallback. They are decrypted at boot by the
  service that needs them, never written to the Nix store. See
  [Secrets and keys](docs/secrets.md).
- **The server** answers on its tailnet address, with only Headscale and New
  Leaf's share links open to the internet. [Section 7](#7-network-exposure)
  lists exactly what is reachable from where.
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
- [**Secrets and keys**](docs/secrets.md) - Changing a secret, adding or
  revoking a YubiKey, and the passphrase fallback.
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
| `ndeploy <host> [switch\|boot]` | Build here and activate on another host over SSH |
| `nrollback` | Go back to the previous generation |
| `nupdate` | Update `flake.lock` |
| `nix fmt` | Format everything (nixfmt, deadnix, statix, shfmt, ruff) |
| `nix flake check` | Build every host and run the formatting and lint checks |
| `nix develop` | A shell with sops, age and the YubiKey plugin |
| `nix build .#iso` | The installer ISO, with SSH and `install-host` |
| `nix run .#install -- <host>` | Install a host, from any NixOS live ISO |
| `sudo nix run .#enroll-tpm` | Re-enroll the TPM2 LUKS keyslot, after a firmware or TPM reset |
| `sudo offsite-restore [entry]` | Restore services' data from the offsite backup ([details](docs/install.md#restoring-data)) |

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
| Harmonia | `cache` | A binary cache of dapple's store |
| Gatus | `status` | Monitoring of all of the above |

Backups: `/persist` to a LUKS-encrypted USB drive with syncoid when it is
plugged in, and the services' data to Storj with restic, daily. Both report
to Gatus.

<br/>

## 7 Network exposure

**From the internet**, the router forwards 443/tcp and 3478/udp to dapple.
There, only two things answer:

- **Headscale** at `vpn`: the control protocol and the DERP relay, which a
  device away from home needs to join the tailnet. Its admin API
  (`/api`, `/swagger`) is refused unless the request comes from the LAN or
  the tailnet.
- **New Leaf's share links** at `cv`: static pages and PDFs at random
  addresses. The editor is not reachable from the internet.

**From the tailnet**, every service in [section 6](#6-services-on-dapple),
over HTTPS on dapple's tailnet address. Their vhosts are bound to that
address only, so they don't answer on the public one.

**From the LAN** (`enp2s0`), besides the above:

- Jellyfin on 8096/tcp, and 7359/udp for clients to discover it.
- Home Assistant on 8123/tcp, plain HTTP.
- `kobo.bw20.nl` on 443, for the Kobo's sync, allowed for the LAN subnet
  only.

**On every interface**, behind the router: SSH on 22, public key only, for
the `nixos` user; and Tailscale's WireGuard on 41641/udp.

**rocinante** opens no ports but Tailscale's 41641/udp, and 5353/udp for
mDNS, to find the installer ISO.

**Outgoing**: restic to Storj, and ACME certificates through Cloudflare DNS.
