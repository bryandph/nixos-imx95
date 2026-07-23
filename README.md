# nixos-imx95

Reusable NixOS support for NXP i.MX 95 boards. The first supported target is
the NXP FRDM-i.MX95.

The initial implementation deliberately keeps NXP's AHAB firmware container
and downstream U-Boot while booting a mainline NixOS kernel and the upstream
`freescale/imx95-15x15-frdm.dtb` through extlinux. It produces an SD image and
does not modify eMMC.

## License boundary

This repository is public, but the required NXP boot container is not.

The repository's MIT license applies only to the original source code here.
The NXP BSP archive and the extracted boot container remain governed by the
license accepted on NXP's download page. The LF6.18.2 Software Content
Register grants its distribution rights only under the conditions in Section
2.3 of NXP's license, including distribution as part of an authorized
NXP-based system rather than as a standalone artifact.

Accordingly:

- the NXP ZIP and extracted boot container are never committed;
- the artifact is represented as `lib.licenses.unfree` with
  `redistributable = false`;
- `requireFile` makes every operator obtain and accept the licensed download;
- Hydra is disabled and substitutes are disabled for the artifact and image;
- the artifact, its store path, and generated image must not be uploaded to a
  public binary cache or attached to a GitHub release.

This is a conservative engineering policy, not legal advice.

## Import the licensed boot container

1. Sign in to NXP, accept the license, and download
   `L6.18.2-1.0.0_MX95` from the
   [official download page](https://www.nxp.com/webapp/Download?colCode=L6.18.2-1.0.0_MX95&appType=license).
2. Import exactly the FRDM boot-container member:

   ```console
   ./scripts/import-nxp-boot-container \
     ~/Downloads/LF_v6.18.2-1.0.0_images_IMX95.zip
   ```

The helper verifies the 8.5 GB source archive, extracts only
`imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all`, verifies its size and
hash, and adds only that 2.8 MB file to the local Nix store. It does not copy
either artifact into the checkout.

## Build

```console
nix run --impure .#fmt
nix flake check --impure -j 1
nix build --impure -j 1 .#packages.aarch64-linux.frdm-imx95-sd-image
```

The image reserves the first 8 MiB, installs the NXP boot container at the
vendor-defined 32 KiB offset, creates a 512 MiB FAT `BOOT` partition containing
generation-aware extlinux entries, and uses an ext4 `NIXOS_SD` root by stable
filesystem identity.

No flashing app is provided. Verify the target block device independently
before writing the resulting image.

## Consumer modules

```nix
{
  imports = [
    inputs.nixos-imx95.nixosModules.boards.frdm-imx95.core
    inputs.nixos-imx95.nixosModules.boards.frdm-imx95.sd-image
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "imx-boot-imx95"
      "nxp-imx95-boot-container"
      "nixos-frdm-imx95.img.zst"
    ];
}
```

The core module selects a mainline kernel with upstream FRDM support, uses the
exact upstream DTB, enables extlinux, and configures the A55 console on
`ttyLP0`. The SD-image module owns only the licensed boot-container boundary
and deterministic image layout.

## Source pointers

- NXP release manifest:
  [`imx-6.18.2-1.0.0.xml`](https://github.com/nxp-imx/imx-manifest/blob/imx-linux-whinlatter/imx-6.18.2-1.0.0.xml)
- NXP machine data:
  [`imx95-evk.inc`](https://github.com/nxp-imx/meta-imx/blob/rel_imx_6.18.2_1.0.0/meta-imx-bsp/conf/machine/include/imx95-evk.inc)
- Release WIC layout:
  [`imx-imx-boot-bootpart.wks.in`](https://github.com/Freescale/meta-freescale/blob/2781242e499e601ef9454009aceed16186a48d9e/wic/imx-imx-boot-bootpart.wks.in)
- Board guide:
  [Getting Started with FRDM-i.MX95](https://www.nxp.com/document/guide/getting-started-with-frdm-imx95:GS-FRDM-IMX95)
