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
scripts/                          install, enroll-tpm, and scripts used by modules
secrets/                          secrets.yaml, encrypted with sops
docs/                             this, install and secrets
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

- **`mkSopsService`**: a oneshot service that decrypts secrets with the
  YubiKey after pcscd is up, retrying while the key enumerates. See
  [Installing a host](install.md#why-the-accounts-start-locked) for why
  secrets are not installed by sops-nix at activation.
- **`mkReverseProxy`**: an nginx vhost at `<subdomain>.bw20.nl`, with an ACME
  certificate, bound to the tailnet address only.
- **`mkUser`**: a user with fish, home-manager, and a password set from
  `user_password_<user>` at boot.

## Checks

`nix flake check` builds every host and checks formatting (treefmt: nixfmt,
deadnix, statix, shfmt, ruff) and statix's lints. `nix fmt` formats.
