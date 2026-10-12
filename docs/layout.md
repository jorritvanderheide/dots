# Layout

The flake is built with [flake-parts](https://flake.parts), and
[import-tree](https://github.com/vic/import-tree) imports every `.nix` file
under `modules/` as a flake-parts module. A new file is picked up without
being listed anywhere; it only needs `jj` or `git` to have seen it, since
flakes only see tracked files.

```
modules/
  features/<area>/<feature>.nix   one NixOS module each: flake.nixosModules.<feature>
  hosts/<host>/configuration.nix  flake.nixosConfigurations.<host>, and its facter.json
  users/<user>/configuration.nix  flake.nixosModules.<user>, made with lib.mkUser
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

A service that keeps data declares it twice: in `my.preservation`, so it
survives a reboot, and in `my.offsite-backup.entries`, so it survives a lost
disk. Backups read a ZFS snapshot of `/persist`, not the live files. An
entry also names the units to stop for `offsite-restore`, and any commands
to load a dump back.

A host picks its features by name from `inputs.self.nixosModules`, in the
same groups as the folders (Core, System, Services, ...), and sets the
`my.*` options in its own module below the list.

## Shared helpers

`modules/flake/lib.nix` holds what several features need, as `inputs.self.lib`:

- **`mkSopsService`**: a oneshot service that decrypts the host's secrets
  with its own age key or a YubiKey (after pcscd is up, retrying while the
  key enumerates). See
  [Installing a host](install.md#why-the-accounts-start-locked) for why
  secrets are not installed by sops-nix at activation.
- **`sopsExtract`**: prints one secret from the host's own file
  (`/etc/sops/secrets.yaml`), with the host's age key (`hostAgeKey`) or a
  YubiKey. `mkSopsService` scripts call it as `sops_extract <key>`.
- **`mkReverseProxy`**: an nginx vhost at `<subdomain>.bw20.nl`, with an ACME
  certificate, bound to the tailnet address and refusing other sources
  (`tailnetOnly`, also usable on its own).
- **`mkUser`**: a user with fish, home-manager, and a password set from
  `user_password_<user>` at boot.

## Comments

Comments say why: a constraint, a failure mode, an upstream quirk. What an
option does goes in its `description`; what changed and when goes in the
commit message, not in a comment about how things used to be.

- A workaround says what would let it go: an issue, a version, or a test to
  rerun ("Drop once NixOS/nixpkgs#569006 reaches nixos-unstable"), not "re-test
  later".
- Comments go on their own line above the code. A trailing comment is for a
  label of a few words, like the name behind a hash.
- Sentences are split with periods, semicolons, colons or parentheses, not
  ` -- `.
- Notes about a folder of non-Nix files, such as where they came from, go in
  a README in that folder, not in the module that uses them.

## Checks

`nix flake check` builds every host and checks formatting (treefmt: nixfmt,
deadnix, statix, shfmt, ruff) and statix's lints. `nix fmt` formats.
