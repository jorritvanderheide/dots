# Layout

The flake is built with [flake-parts](https://flake.parts), and
[import-tree](https://github.com/vic/import-tree) imports every `.nix` file
under `modules/` as a flake-parts module. A new file is picked up without
being listed anywhere; it only needs `jj` or `git` to have seen it, since
flakes only see tracked files.

```
modules/
  features/<area>/<feature>.nix   one NixOS module each: flake.nixosModules.<feature>
  features/<area>/<feature>/      a feature too big for one file, and the files it reads
  bundles/<bundle>.nix            features that come as one: flake.nixosModules.base, .desktop
  hosts/<host>/configuration.nix  flake.nixosConfigurations.<host>, and its facter.json
  users/<user>/configuration.nix  flake.nixosModules.<user>, made with lib.mkUser
  users/<user>/<part>.nix         more of the same module: mail, calendars, SSH hosts
  flake/                          checks, formatter, dev shell, apps, lib, installer ISO
scripts/                          install, enroll-tpm, offsite-prune, and scripts used by modules
secrets/                          <host>.yaml, encrypted with sops
docs/                             this, install, secrets and security
```

## Features

A feature is one NixOS module, named after the file, that sets up one thing:
`terminal`, `zfs`, `immich`. Desktop and app features configure the user
through `home-manager.sharedModules`. Options live under `my.<feature>`:
services do nothing until `my.<service>.enable` is set, and other features
take settings there, like `my.compositor.outputs`.

Settings for a host are NixOS options, set in the host. A home-manager
module reads them through the enclosing NixOS module, bound in a `let`
(the home-manager module rebinds `config`). Settings for a person, like
their git identity or SSH keys, are set in `users/<user>`, as home-manager
options where the feature declares some (`my.git`).

A feature too big for one file becomes a folder. Each `.nix` file in it
defines the same `flake.nixosModules.<feature>`, and flake-parts merges
them into one module: `services/home-assistant/` keeps the service in
`default.nix` and the house's automations in `automations.nix`;
`services/servarr/` has a file per app, `desktop/theming/` a file per themed
target (`gtk.nix`, `zen.nix`, ...). The folder also holds the non-Nix files
the feature reads, like theming's `noctalia-templates/` or keyboard-remap's
`main.kbd`. A user can be split the same way.

A service that keeps data declares it twice: in `my.preservation`, so it
survives a reboot, and in `my.offsite-backup.entries`, so it survives a lost
disk. Backups read a ZFS snapshot of `/persist`, not the live files. An
entry also names the units to stop for `offsite-restore`, and any commands
to load a dump back.

A service with a web page also declares what the status page checks: the
`status` of its `mkReverseProxy`, or `my.gatus.endpoints` directly for one
without.

A service that needs a secret declares it in `sops.secrets`, by its key in
the host's file, and reads it from `config.sops.secrets.<key>.path`; one
that wants it inside a file of its own, like an env file, gets a
`sops.templates` entry with `config.sops.placeholder.<key>` in it.
sops-nix decrypts them at activation, with the host's own age key
(`hostAgeKey`), so they exist before any service starts.

A host starts from the `base` bundle: the core, the system and shell
features every host has, and offsite-backup and gatus, whose entries any
feature may declare; a host that doesn't enable them ignores the entries. A host with a screen adds `desktop`: the desktop features, which
lean on each other (app2unit, niri, theming, noctalia) and so come as one,
and research's settings, which the app and research features read. Those
build on `desktop`. The host picks the rest by name from
`inputs.self.nixosModules`, in the same groups as the folders (System,
Services, ...), and sets the `my.*` options in its own module below the
list.

## Shared helpers

`modules/flake/lib.nix` holds what several features need, as `inputs.self.lib`:

- **`mkReverseProxy`**: an nginx vhost at `<subdomain>.<my.ingress.domain>`,
  with an ACME certificate, bound to the tailnet address and refusing other
  sources (`tailnetOnly`, also usable on its own), and its `status`: the
  name and group the status page checks it under. The `ingress` feature
  runs nginx and ACME for it.
- **`site`**: facts more than one host needs: the domain, Headscale's
  domain, dapple's tailnet address and the LAN's subnet. The host-local
  side, like which interface is on the LAN, is `my.lan`.
- **`mkUser`**: a user with fish, home-manager, and a password set from
  `user_password_<user>` at boot.

## Ordering

Inside an attribute set, an attribute's place follows from its shape and
name only:

1. Single-line attributes first, alphabetical, without blank lines between
   them. A plain value that nixfmt wrapped onto a second line still counts
   as single-line.
2. Then multi-line attributes, alphabetical, with a blank line between each.

A comment doesn't move an attribute: a commented one-liner keeps its
alphabetical place among the single lines, with a blank line above its
comment and below the line. A comment can also cover a run of one-liners
directly below it, like `min-free` and `max-free`: the run stays together,
alphabetical inside, in the place of its first name, with a blank line
above the comment and below the run. A comment about the whole set sits at
its top, followed by a blank line.

Alphabetical goes by the attribute path as written, ignoring case and
quotes, so `my.*`, `networking.*` and `services.*` each end up together.

Exceptions:

- `inherit` lines, then `enable`, lead their set.
- `mkOption` arguments keep nixpkgs' order: `type`, `default`, `example`,
  `description`.
- A module's `imports`, `options` and `config` come in that order.
- `let` bindings and lists keep their order: a `let` reads best top-down,
  and in a list the order can matter.
- Function arguments are alphabetical, with `...` last.

`nix fmt` applies this order (`scripts/nix-order.py`, before nixfmt), so
the flake check fails on a file that is out of order. Attribute order never
changes what Nix evaluates: a reorder that leaves every host's closure the
same, apart from the revision it's built from, changed nothing but the
layout.

## Comments

Comments say why: a constraint, a failure mode, an upstream quirk. What an
option does goes in its `description`; what changed and when goes in the
commit message, not in a comment about how things used to be.

- A workaround says what would let it go: an issue, a version, or a test to
  rerun ("Drop once NixOS/nixpkgs#569006 reaches nixos-unstable"), not "re-test
  later".
- Comments go on their own line above the code. A trailing comment is for a
  label of a few words, like the name behind a hash.
- Other settings are named, not pointed at with "above" or "below":
  sorting moves them.
- Sentences are split with periods, semicolons, colons or parentheses, not
  ` -- `.
- Notes about a folder of non-Nix files, such as where they came from, go in
  a README in that folder, not in the module that uses them.

## Checks

`nix flake check` builds every host and checks formatting (treefmt: nix-order,
nixfmt, deadnix, statix, shfmt, ruff) and statix's lints. `nix fmt` formats.
