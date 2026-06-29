<div align="center">
   <img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="96px" height="96px" />
   <br>
   <br>
   <h1>
      Jorrit's NixOS configuration & dots
      <br>
      <br>
   </h1>
</div>

## Overview

A flake-based NixOS configuration for two hosts:

- **rocinante** — a laptop/workstation (niri Wayland desktop, full app suite).
- **dapple** — a bare-metal home server (Jellyfin, Home Assistant, Vaultwarden,
  Headscale, \*arr stack, backups, …).

Both boot with Secure Boot + Measured Boot (lanzaboote), an ephemeral ZFS root
with [preservation] for state, LUKS+TPM2 disk encryption, and [sops-nix] for
secrets. Hardware is described declaratively via [nixos-facter].

## Layout

```
flake.nix                 # inputs only; outputs are assembled by import-tree
modules/
  flake/                  # flake-parts plumbing: lib helpers, formatter, checks, home-manager
  features/
    core/                 # boot, disk, zfs, preservation, secrets, kernel, locale
    system/               # ssh, sudo, networking, vpn
    services/             # one file per server service (dapple)
    desktop/              # niri compositor, shell, keybinds, theming, session, …
    apps/                 # per-application config (rocinante)
    dev/                  # git/jj, direnv, virtualization, coding-agent
    shell/, hardware/
  hosts/<host>/           # configuration.nix + facter.json per machine
  users/<user>/           # per-user config (home-manager via lib.mkUser)
```

[`import-tree`](https://github.com/vic/import-tree) auto-discovers every `.nix`
file under `modules/`, so there is no central module registry — adding a file is
enough to register it.

## Conventions

Every feature is a NixOS module exposed under `flake.nixosModules.<name>` and
gated behind an option in the **`my.*`** namespace (e.g. `my.jellyfin.enable`).
The `my.*` prefix marks "this repo's options" and avoids collisions with
upstream NixOS/home-manager options. The standard module shape is:

```nix
{
  flake.nixosModules.foo =
    { config, lib, pkgs, ... }:
    let
      cfg = config.my.foo;
    in
    {
      options.my.foo.enable = lib.mkEnableOption "the foo service";

      config = lib.mkIf cfg.enable {
        # ...
      };
    };
}
```

Persistent state is declared via `my.preservation.{systemDirectories,homeDirectories,...}`
(see `modules/features/core/preservation.nix`); the ephemeral root is wiped on
every boot, so anything not preserved is lost by design.

## Adding a module

1. Create `modules/features/<category>/<name>.nix` following the shape above.
2. Add `<name>` to the host's import list in `modules/hosts/<host>/configuration.nix`.
3. Set `my.<name>.enable = true;` (plus any options) on the host.

## Adding a host

1. Generate hardware facts: `nixos-facter -o modules/hosts/<host>/facter.json`.
2. Add `modules/hosts/<host>/configuration.nix` defining
   `flake.nixosConfigurations.<host>` with the shared modules + host options
   (use an existing host as a template).

## Working with the repo

```sh
nbuild        # build the current host's configuration (dry-run/test)
nswitch       # build + switch
nix fmt       # treefmt: nixfmt + deadnix + statix + prettier
nix flake check   # formatting + statix + builds both hosts
```

Version control uses [jujutsu] (`jj`) on a colocated git repo. Secrets live in
`secrets/` and are decrypted by sops-nix using an age key derived at boot from
the host's SSH key.
