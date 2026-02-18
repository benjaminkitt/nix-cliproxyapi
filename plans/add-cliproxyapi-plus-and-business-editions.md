# Plan: Add CLIProxyAPIPlus and CLIProxyAPIBusiness editions

## Overview

Extend the nix-cliproxyapi repository from a single-edition (CLIProxyAPI) Nix flake to support three independent editions: **CLIProxyAPI** (base), **CLIProxyAPIPlus**, and **CLIProxyAPIBusiness**. Each edition has its own version, hashes, GitHub repo, release asset naming, binary name, and license.

## Edition Details

| Attribute | CLIProxyAPI | CLIProxyAPIPlus | CLIProxyAPIBusiness |
|-----------|-------------|-----------------|---------------------|
| Nix attr name | `cliproxyapi` | `cliproxyapi-plus` | `cliproxyapi-business` |
| GitHub repo | `router-for-me/CLIProxyAPI` | `router-for-me/CLIProxyAPIPlus` | `router-for-me/CLIProxyAPIBusiness` |
| Archive prefix | `CLIProxyAPI` | `cli-proxy-api-plus` | `cpab` |
| Binary in tarball | `cli-proxy-api` | `cli-proxy-api-plus` | `cpab` |
| Version format | `6.8.8` (semver) | `6.8.16-0` (semver+build) | `2026.7.1` (calendar) |
| Default port | 8317 | 8317 | 8318 |
| License | MIT | MIT | SSPL-1.0 |

## Architecture: Data-driven `editions` attrset

Define an `editions` attrset in `flake.nix` containing all per-edition metadata. All packages, apps, and overlay entries are derived from this single source of truth using `builtins.mapAttrs`.

All editions install their binary as `$out/bin/cliproxyapi` so the NixOS/Darwin modules work without changes (they already call `${cfg.package}/bin/cliproxyapi`).

---

## Tasks

### Task 1: Restructure `flake.nix` with multi-edition support
- **Vibe Kanban Issue ID**: `035701f5-7dc4-4ef2-b683-0a084f9a23cf`
- **File**: `flake.nix`
- Replace single `version`/`hashes` with `editions` attrset
- Generalize `mkPackage` to accept edition metadata
- Generate `packages.*`, `apps.*`, and `overlays.default` from editions
- Use placeholder hashes for new editions initially

### Task 2: Rewrite `scripts/update-version.sh` for multi-edition support
- **Vibe Kanban Issue ID**: `ee31289a-bb61-4b81-acbf-855179da2e85`
- **File**: `scripts/update-version.sh`
- Change interface to `$0 <edition> <version>`
- Add edition lookup tables for repo name and archive prefix
- Use multiline perl replacement scoped to edition blocks
- Run for both new editions to populate real hashes

### Task 3: Rewrite `.github/workflows/update-flake.yml` for multi-edition support
- **Vibe Kanban Issue ID**: `9d8ced11-a88c-4e7e-9924-85c3f9f71b20`
- **File**: `.github/workflows/update-flake.yml`
- Matrix strategy checking all three repos independently
- Separate PRs per edition
- `workflow_dispatch` with edition choice dropdown
- `fail-fast: false`

### Task 4: Update `README.md` documentation
- **Vibe Kanban Issue ID**: `fb77ce08-ba7a-4835-9690-0c586b38c2ba`
- **File**: `README.md`
- Add editions comparison table
- Update Quick Start, module examples, overlay section
- Add license notes for SSPL

### Task 5: Update module package option descriptions (cosmetic)
- **Vibe Kanban Issue ID**: `488bc524-7b56-4aea-8215-69116f45a4be`
- **Files**: `modules/nixos.nix`, `modules/darwin.nix`
- Update `package` option description to mention all three editions

---

## Verification

1. `nix flake check` — passes evaluation
2. `nix build .#cliproxyapi` — builds successfully (existing base)
3. `nix build .#cliproxyapi-plus` — builds successfully with real hashes
4. `nix build .#cliproxyapi-business` — builds successfully with real hashes
5. `nix run .#cliproxyapi-plus -- --help` — binary runs correctly
6. `nix run .#cliproxyapi-business -- --help` — binary runs correctly
7. `./scripts/update-version.sh cliproxyapi 6.8.8` — updates only the base edition block
