# AGENTS.md

This repository provides reusable NixOS support for NXP i.MX 95 boards.

## Repository shape

- `flake.nix` is minimal and imports every public `modules/**/*.nix` file
  through `import-tree`.
- Each file under `modules/` is one dendritic flake-parts module.
- Reusable NixOS features are exported through
  `flake.modules.nixos` and aliased under `nixosModules`.
- Package expressions that are not flake-parts modules live under `packages/`.

## Commands

- Use `nix run --impure .#fmt` for formatting.
- Use `nix flake check --impure -j 1` for the standard check gate.
- Build the image with
  `nix build --impure -j 1 .#packages.aarch64-linux.frdm-imx95-sd-image`.
- Stage new files before flake evaluation so Git-backed flakes can see them.

## Licensed NXP artifacts

Never commit, publish, attach to a release, or upload to a public binary cache
the NXP BSP archive, extracted boot container, or an SD image containing that
boot container.

The public repository contains only:

- source pointers and expected hashes;
- a local extraction/import helper;
- an unfree `requireFile` package boundary; and
- image construction code.

The repository's MIT license covers only original source code. It does not
cover any NXP artifact supplied by an operator.
