# Security

What keeps whom out of what, on both hosts, mostly dapple. The ports
themselves are listed in the README's
[Network exposure](../README.md#7-network-exposure), and the keys in
[Secrets and keys](secrets.md). This page is the reasoning behind both.

## Who is kept out of what

**The internet** reaches three things on dapple, at the home address,
through the router's port forward: Headscale's control protocol and DERP
relay at `vpn`, New Leaf's share links at `cv`, and meetinn (a demo) at
`inn`. No proxy sits in front, so TLS ends on dapple and nobody between
reads share links or meetinn's tokens, at the price of a public home
address. Headscale's admin API (`/api`, `/swagger`) only answers tailnet
addresses, so in practice nobody over the network: the `headscale` CLI uses
a local socket. Everything else is bound to dapple's tailnet address.

**A tailnet device** gets what Headscale's
[policy](../modules/features/services/headscale/headscale-policy.hujson) grants it:

- every device: the services on dapple, over HTTPS;
- a person's own devices: each other, on every port, as without a policy;
- rocinante: SSH and Syncthing on dapple;
- two phones: the home LAN, through dapple's subnet route, for the camera.
  Not rocinante, which doesn't take the route: accepting it would send its
  LAN traffic through dapple even at home.

The build checks the policy's addresses against `lib.site`, so a changed
subnet or address can't leave a grant pointing elsewhere.

dapple is tagged `tag:server`, so it isn't one of anyone's own devices: no
blanket device-to-device access to it, and New Leaf doesn't take it for a
person. The firewall holds the same line a second time: it is nftables, so
its tailnet rules (443, 22 and 22000) apply even though tailscaled accepts all
tailnet traffic in its own table. Behind that, the apps ask for their own
login, except Gatus's read-only status page, and New Leaf's editor, which
goes by your tailnet user and lets every one edit every CV: the *arr apps
and qBittorrent with a forms login that a "local" address doesn't skip
(behind nginx every visitor is 127.0.0.1), and Bazarr, whose default is
no login at all.

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
  desktop session only (polkit's default policy);
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

**A CI job** from Codeberg runs on dapple itself (the Forgejo runner), as
the runner's dynamic user, so it gets what a process on dapple gets, and
less: its unit is cut off from localhost, the LAN and the tailnet
(`IPAddressDeny`), since dapple's vhosts let in anything from dapple's own
tailnet address, and sees no `/home`. Its DNS is Quad9's, the router's
being on the LAN. It builds through the Nix daemon as an allowed, not a
trusted, user: sandboxed builds, no say over substituters or keys. One job
runs at a time.

**Someone with the `nixos` SSH key** still needs the sudo password, or one
of the YubiKeys and a touch: sudo on dapple also takes a signature from a
FIDO2 key on either (`pam_rssh`), through an agent rocinante forwards with
only those keys in it. The login key isn't one of them. Nix isn't a way
around it either: dapple's Nix trusts only root, and what `ndeploy` copies
over has to be signed by rocinante's deploy key (`rocinante-1`).

**A machine posing as dapple**, say one at 192.168.1.162 on another
network, gets refused: rocinante pins dapple's host key and checks it
strictly, so neither the forwarded agent nor the sudo password goes there.
The key is a sops secret, so a reinstalled dapple has it from its first
boot.

**One host taken over** doesn't give up the other's secrets: each host has a
file of its own, readable by its own key, and each has its own LUKS, root
and restic passwords. rocinante doesn't take packages from dapple, which
runs no binary cache, so a taken-over dapple can't push code to the
laptop. Editing dapple's secrets needs a YubiKey's PIN and a touch, on
either key, so a stolen laptop with a YubiKey still in doesn't open the
server. Neither key's PUK is the factory default, or anyone holding it
could set a new PIN with it.

**Ransomware on a host** can't take the offsite backups along. Each host's
Storj credentials reach only its own `restic/<host>/` in the `offsite`
bucket, and can't delete. Storj also refuses to overwrite an object without
the right to delete it, so the host can add to its backups but not wipe,
overwrite or encrypt them (tested on the real bucket: the repository's
`config` can't be replaced). Pruning and `restic check` need deletes, so
they run by hand from rocinante, every few months, with the owner's key
from Bitwarden: `nix run .#offsite-prune -- <host>`. The same goes for a
new repository's first backup, which restic can't finish without deleting
its own lock ([A first or very large backup](secrets.md#a-first-or-very-large-backup)).

**A thief** gets encrypted disks, and no boot menu editor to add `init=` or
a debug shell at boot. The hosts boot with secure boot, with our own keys,
and the TPM only unlocks a disk for that
([Secure boot](install.md#secure-boot)). rocinante's disk also opens with
either YubiKey's FIDO2 slot, which needs the key's PIN and a touch, so the
laptop and a key together still aren't enough.

## Checked by hand

What the configuration can't say, checked on 2026-10-10; the router's
forwards, the deSEC token and the 403s from outside again on 2026-10-16.
Worth checking again after changing the router, the DNS or an app's own
settings.

- The router forwards only 443/tcp and 3478/udp to dapple, nothing else.
- Vaultwarden's `ADMIN_TOKEN` is an argon2 hash, Calibre-Web's admin
  password isn't the default, and qBittorrent's password is long and random.
- The deSEC token (for ACME) can only write the `_acme-challenge` TXT
  record, and only from the home address: a default policy without write,
  one TXT policy for `_acme-challenge`, and `allowed_subnets`. With more,
  it could point `vpn` elsewhere and get a valid certificate for it, or
  rewrite the mail records. It can still read the whole zone, as every
  deSEC token can.
- The router passes internet visitors' own addresses on, so the Kobo vhost's
  LAN rule holds: from mobile data,
  `curl --resolve kobo.bw20.nl:443:<home-ip> https://kobo.bw20.nl/kobo/x`
  answers 403, and so does `https://vpn.bw20.nl/api/v1/node`.
- Jellyfin's Known Proxies has 127.0.0.1, so it sees the real client
  address.

Vaultwarden's signups and invitations need no check: they're off in the
configuration, which also rewrites what its admin page saves before each
start, since that would otherwise win.

## Accepted on purpose

- **A CI workflow runs code on dapple**: whoever can start one on meetinn
  (its committers, and a fork's pull request unless Codeberg holds those
  for approval) runs it as the runner's user, with the internet. Enough to
  send spam or mine from the home address, or fill the disk with Nix
  builds; not enough to reach the services, the LAN or the tailnet, or to
  become root. The VM test needs KVM, which Codeberg's own runners lack.
- **rocinante forwards an SSH agent to dapple**, the one with only the
  YubiKeys' sudo keys. While you're connected, anything on dapple running
  as `nixos` can ask it to sign, and run sudo if you touch the key. The
  YubiKey blinks when asked, so only touch it right after you ran sudo.
- **sudo on dapple remembers a touch (or password) for 5 minutes across
  all of `nixos`'s sessions**, not just the terminal it was typed in, so a
  deploy takes one touch instead of one for each of nh's sudo calls. In that
  window, anything running as `nixos` can use sudo too, but only what you
  start over SSH runs as `nixos`: every service has a user of its own.
- **Headscale listens on 127.0.0.1:8085**, a port any local process could
  take while Headscale restarts, and then act as control server. Moving it
  below 1024 would need dapple's own node to re-authenticate, the node every
  service address hangs on. Vaultwarden on 8222 is the same, and its
  sandbox (`PrivateUsers`) rules out a port below 1024.
- **The installer ISO runs the installer from Codeberg's `main`**, so it
  doesn't go stale and installs whatever was pushed last. A compromised
  Codeberg account could feed it a bad one; the same account would reach
  your next fetch anyway.
- **Certificate Transparency logs still list the services' names**, from
  before the wildcard certificate. The names aren't secret; the services
  aren't reachable from the internet.
- **qBittorrent's password hash is in the repository** (PBKDF2, in its
  declared config), which is fine with a long, random password like its
  own.
- **Headscale's `/version` is public**, with its exact version.
- **ntfy's state directory is 0777**, as `DynamicUser` gives it no fixed
  owner to preserve it with. It sits in `/var/lib/private`, which systemd
  keeps at 0700, so no other user reaches it.
- **rocinante's keyring has an empty password**, since the session logs in
  automatically and has no password to unlock it with. LUKS protects it on
  disk; while logged in, an unlocked keyring is just as readable.
- **eduroam doesn't check RU's server** (`wifi.nix`): no CA and no
  `domain-suffix-match`, since RU's server doesn't send its intermediate
  certificate and wpa_supplicant won't find it locally, so a pinned CA
  fails every handshake. An access point calling itself eduroam can then
  capture an MSCHAPv2 exchange, which can be cracked offline into the RU
  password. It's worth trying again, with the intermediate itself as the
  CA, the next time on campus.

## Checking it

From rocinante:

```sh
curl -m5 http://100.64.0.1:6767/        # times out: only 443, 22 and 22000 on the tailnet
curl -sk -m5 https://100.64.0.1/ -H 'Host: x'   # refused: unknown name
ssh nixos@dapple nix store info          # Trusted: 0
ssh -t dapple sudo -k true               # a YubiKey touch, no password
```

On dapple:

```sh
sudo headscale nodes list                # dapple has tag:server
sudo nft list ruleset                    # the firewall, as nftables
systemctl --failed                       # nothing: sops-nix decrypted without a YubiKey
```
