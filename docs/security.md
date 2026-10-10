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
server.

**A thief** gets encrypted disks, and no boot menu editor to add `init=` or
a debug shell at boot. But see below: the TPM still unlocks the disks for
any system booted on the same board.

## Still open

- **The TPM unlocks for anything.** Its LUKS keyslot isn't bound to any PCR,
  and secure boot is off, so a thief who boots another system on the same
  machine gets the disk unlocked, and on dapple that includes its age key,
  and with it `secrets/dapple.yaml`. The fix: secure boot with our own keys
  (lanzaboote), a firmware password, and the TPM re-enrolled with
  `--tpm2-pcrs=7`. Check with `sudo cryptsetup luksDump
  /dev/disk/by-partlabel/disk-main-luks`: the `tpm2` token should list PCR 7.
- **The offsite backups can be deleted from the hosts.** The Storj
  credentials allow deletes (restic prunes after each backup) and are shared
  by both hosts, so ransomware on either can wipe both hosts' backups. The
  USB copy only survives if it is unplugged at the time. The fix: a bucket
  with versioning and Object Lock, and a grant per host, limited to its own
  `restic/<host>/` and without the right to remove locked versions.
  Storj's versioning is in beta, so this needs a test on a scratch bucket
  first.
- **To check by hand**, since the configuration doesn't say:
  - Vaultwarden's `ADMIN_TOKEN` is unset or an argon2 hash, and invitations
    are off.
  - Calibre-Web's `admin` account doesn't have its default password.
  - The Cloudflare token can only edit DNS in `bw20.nl`: with more, it can
    point `vpn` elsewhere and get a valid certificate for it.
  - From mobile data, `https://vpn.bw20.nl/api/v1/apikey` answers 403.
  - Jellyfin's Known Proxies has 127.0.0.1, so it sees the real client
    address.
  - qBittorrent's password is long and random: its hash is in the
    repository (below).

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
  declared config), which is fine as long as the password is long and
  random.
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
