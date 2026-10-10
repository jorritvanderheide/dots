# Security

What keeps whom out of what, on both hosts, mostly dapple. The ports
themselves are listed in the README's
[Network exposure](../README.md#7-network-exposure), and the keys in
[Secrets and keys](secrets.md). This page is the reasoning behind both, and
what is still open.

## Who is kept out of what

**The internet** reaches two things on dapple, through Cloudflare: Headscale's
control protocol and DERP relay at `vpn`, and New Leaf's share links at `cv`.
Headscale's admin API (`/api`, `/swagger`) only answers tailnet addresses,
which never reach it through Cloudflare, so in practice nobody over the
network: the `headscale` CLI uses a local socket. A name no vhost claims
gets no certificate and no answer. Everything else is
bound to dapple's tailnet address.

**A tailnet device** gets what Headscale's
[policy](../modules/features/services/headscale-policy.hujson) grants it:

- every device: the services on dapple, over HTTPS;
- rocinante: SSH on dapple;
- rocinante, pixel-10-pro and pixel-jeltje: the home LAN, through dapple's
  subnet route (the phones for the camera).

dapple is tagged `tag:server`, so it isn't one of anyone's own devices: no
blanket device-to-device access to it, and New Leaf doesn't take it for a
person. The firewall holds the same line a second time: it is nftables, so
its tailnet rules (443 and 22) apply even though tailscaled accepts all
tailnet traffic in its own table. Behind that, the apps ask for their own
login, except Gatus's read-only status page: the *arr apps and qBittorrent
with a forms login that a "local" address doesn't skip (behind nginx every
visitor is 127.0.0.1), and Bazarr, whose defaults were no login at all.

**A LAN device** gets SSH (from the LAN subnet only) and the Kobo sync API at
`kobo.bw20.nl/kobo/`. Not Jellyfin's or Home Assistant's plain-HTTP ports:
they are closed, and clients use HTTPS over the tailnet. The tailnet's vhosts
refuse any source outside 100.64.0.0/10, so a LAN device that routes dapple's
tailnet address through dapple's LAN address still gets nothing: Linux
accepts a packet for a local address on any interface, but tailscaled drops
tailnet sources that don't arrive on `tailscale0`.

**A process on dapple**, such as a compromised service:

- can't decrypt: dapple's age key is root's alone (0400, in a 0700
  directory), and the YubiKey, where one is plugged in, answers root and a
  desktop session only (a polkit rule in `secrets.nix`);
- can't read the decrypted secrets: they are in `/run/secrets`, readable by
  root or the one service that needs them, and kept off command lines
  (`/proc/*/cmdline` is readable by everyone);
- can't read other services' state: the directories with passwords or
  tokens in them are 0700, Prowlarr's 0777 one inside a 0700 parent;
- can't become root through Nix: dapple's Nix trusts only root;
- can't plant a lasting SSH key: SSH reads only the keys declared in this
  repository, not `~/.ssh`;
- in Home Assistant's case, can't rewrite the firewall or sniff traffic:
  it runs without `CAP_NET_ADMIN` and `CAP_NET_RAW`.

**Someone with the `nixos` SSH key** still needs the sudo password: Nix
isn't a way around it any more, and what `ndeploy` copies over has to be
signed by rocinante's deploy key (`rocinante-1`).

**One host taken over** doesn't give up the other's secrets: each host has a
file of its own, readable by its own key, and each has its own LUKS, root
and restic passwords. rocinante doesn't take packages from dapple (there is
no dapple cache any more), so a taken-over dapple can't push code to the
laptop. Editing dapple's secrets from rocinante needs the admin key's PIN
and a touch, so a stolen laptop with its YubiKey still in doesn't open the
server. The YubiKey's PUK isn't the factory default either, or anyone
holding the key could set a new PIN with it.

**Ransomware on a host** can't take the offsite backups along. Each host's
Storj credentials reach only its own `restic/<host>/` in the `offsite`
bucket, and can't delete. Storj also refuses to overwrite an object without
the right to delete it, so the host can add to its backups but not wipe,
overwrite or encrypt them (tested on the real bucket: the repository's
`config` can't be replaced). Pruning and `restic check` need deletes, so
they run by hand from rocinante, every few months, with the owner's key
from Bitwarden: `nix run .#offsite-prune -- <host>`.

**A thief** gets encrypted disks, and no boot menu editor to add `init=` or
a debug shell at boot. On rocinante, secure boot runs with our own keys and
the TPM only unlocks the disk for that ([Secure boot](install.md#secure-boot)).
dapple isn't there yet: see below.

## Still open

- **dapple's TPM still unlocks for anything**, until its secure boot is
  finished (rocinante's is). Its LUKS keyslot isn't bound to PCR 7 yet, so
  a thief who boots another system on it gets the disk unlocked, with
  dapple's age key, and with that `secrets/dapple.yaml`. The steps are in
  [Secure boot](install.md#secure-boot). Check with `sudo cryptsetup
  luksDump /dev/disk/by-partlabel/disk-main-luks`: the `systemd-tpm2` token
  should list PCR 7.

## Checked by hand

What the configuration can't say, checked on 2026-10-10. Worth checking
again after changing the router, Cloudflare or an app's own settings.

- Vaultwarden's `ADMIN_TOKEN` is an argon2 hash, Calibre-Web's admin
  password isn't the default, and qBittorrent's password is long and random.
- The Cloudflare token (for ACME) can only edit DNS in `bw20.nl`: with
  more, it could point `vpn` elsewhere and get a valid certificate for it.
  It's the account's only API token; three leftover Cloudflare Tunnel
  tokens, which nothing here used, were deleted.
- The router passes internet visitors' own addresses on, so the Kobo vhost's
  LAN rule holds: from mobile data,
  `curl --resolve kobo.bw20.nl:443:<home-ip> https://kobo.bw20.nl/kobo/x`
  answers 403. (Headscale's `/api` can't tell: `vpn` goes through
  Cloudflare, so it refuses everyone.)
- Jellyfin's Known Proxies has 127.0.0.1, so it sees the real client
  address.

Vaultwarden's invitations need no check: they're off in the configuration,
which also rewrites what its admin page saves before each start, since that
would otherwise win.

## Accepted on purpose

- **Headscale listens on 127.0.0.1:8085**, a port any local process could
  take while Headscale restarts, and then act as control server. Moving it
  below 1024 would need dapple's own node to re-authenticate, the node every
  service address hangs on. Vaultwarden on 8222 is the same, and its
  sandbox (`PrivateUsers`) rules out a port below 1024.
- **The installer ISO runs the installer from Codeberg's `main`**, so it
  doesn't go stale and installs whatever was pushed last. A compromised
  Codeberg account could feed it a bad one; the same account would reach
  your next fetch anyway.
- **Every service has its own certificate**, so Certificate Transparency
  logs list their names. The names aren't secret; the services aren't
  reachable from the internet.
- **qBittorrent's password hash is in the repository** (PBKDF2, in its
  declared config), which is fine with a long, random password like its
  own.
- **Headscale's `/version` is public**, with its exact version.

## Checking it

From rocinante:

```sh
curl -m5 http://100.64.0.1:6767/        # times out: only 443 and 22 on the tailnet
curl -sk -m5 https://100.64.0.1/ -H 'Host: x'   # refused: unknown name
ssh nixos@dapple nix store info          # Trusted: 0
```

On dapple:

```sh
sudo headscale nodes list                # dapple has tag:server
sudo nft list ruleset                    # the firewall, as nftables
systemctl --failed                       # the secret services decrypt without a YubiKey
```
