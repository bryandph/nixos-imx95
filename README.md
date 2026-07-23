# nixos-imx95

Reusable NixOS support for NXP i.MX 95 boards. The first supported target is
the NXP FRDM-i.MX95.

The flake builds U-Boot, TF-A, OP-TEE, System Manager, OEI, and imx-mkimage
from release-pinned source. Only NXP's ELE firmware and four Synopsys
LPDDR4X training binaries remain operator-supplied. Those components are
assembled with imx-mkimage's `flash_a55` target, which retains the M33
System Manager but omits NXP's unrelated prebuilt M7 demonstration.

The source-built provider is available for SD acceptance alongside the
previous complete-container compatibility provider. The compatibility
provider remains the module default until source-built SD and eMMC hardware
acceptance succeeds. Both paths boot a mainline NixOS kernel and the upstream
`freescale/imx95-15x15-frdm.dtb` through extlinux. Builds never modify a
device.

## License boundary

This repository is public, but the required NXP firmware and every aggregate
output embedding it are not redistributable.

The repository's MIT license applies only to the original source code here.
The ELE and DDR firmware distributions, their extracted members, the
source-assembled container, the complete compatibility container, and both
generated images remain governed by NXP's license. The LF6.18.20 Software
Content Register grants distribution rights only under the conditions in
Section 2.3 of that license, including distribution as part of an authorized
NXP-based system rather than as standalone artifacts.

Accordingly:

- NXP distributions and extracted firmware are never committed;
- each of the five required firmware members has a separate hash-pinned
  `requireFile` package;
- open-source intermediate packages retain their actual upstream licenses;
- firmware and aggregate outputs use `lib.licenses.unfree` with
  `redistributable = false`;
- import requires an explicit `--accept-license` acknowledgement;
- Hydra and substitutes are disabled for firmware-bearing containers, checks,
  and images; and
- firmware, dependent store paths, containers, and generated images must not
  be uploaded to a public cache or attached to a GitHub release.

This is a conservative engineering policy, not legal advice.

## Import the granular licensed firmware

Obtain these release-pinned NXP self-extracting distributions after reviewing
and accepting their licenses:

- `firmware-ele-imx-2.0.6-c0b284c.bin`
- `firmware-imx-8.32-1991416.bin`

The official URLs and distribution/member hashes live in
`packages/imx95-lf-6.18.20-2.0.0.nix`. Import exactly the required members:

```console
./scripts/import-nxp-firmware --accept-license \
  ~/Downloads/firmware-ele-imx-2.0.6-c0b284c.bin \
  ~/Downloads/firmware-imx-8.32-1991416.bin
```

The helper verifies both distributions, invokes their licensed extraction
flow, extracts only the B0 ELE image and four FRDM LPDDR4X members, verifies
every size and hash, and adds only those five files to the local Nix store.
Temporary extraction is removed on exit. Nothing is copied into the checkout.

For compatibility rollback, the older complete NXP container can still be
imported independently:

```console
./scripts/import-nxp-boot-container \
  ~/Downloads/LF_v6.18.20-2.0.0_images_IMX95EVK.zip
```

## Build

```console
nix run --impure .#fmt
nix flake check --impure -j 1
nix build --impure -j 1 \
  .#packages.aarch64-linux.frdm-imx95-source-boot-container
nix build --impure -j 1 \
  .#packages.aarch64-linux.frdm-imx95-source-built-sd-image
```

`frdm-imx95-sd-image` remains the compatibility-provider image during
hardware acceptance. `frdm-imx95-source-built-sd-image` is the candidate
image. The checks parse its AHAB inventory, reject missing/corrupt/unsafe
inputs, compare two clean assemblies byte-for-byte, and verify its exact bytes
at the raw SD offset.

NixOS consumers should build
`config.system.build.frdmImx95SdImage`, not the standard module's raw
`config.system.build.sdImage`; the FRDM-specific output carries the unfree,
non-redistributable, no-substitutes metadata required by the embedded NXP
artifact.

The image reserves the first 8 MiB, installs the NXP boot container at the
vendor-defined 32 KiB offset, and installs a generated U-Boot environment at
NXP's 7 MiB offset. The environment supplies non-overlapping kernel, DTB, and
initrd load addresses and makes bootflow consume the generation-aware extlinux
entry at the FAT root. The 512 MiB FAT `BOOT` partition is marked active for
NXP U-Boot and mounts at `/boot`, so later NixOS generations update the
extlinux entry on the real boot filesystem. The ext4 root uses the stable
`NIXOS_SD` identity and expands on first boot by resolving its kernel
major/minor identity through sysfs rather than assuming a device-node minor
number.

No flashing app is provided. Preserve an accepted compatibility-provider SD
card while testing the source-built image. The manual eMMC procedure below
requires an independently verified target and must not be used for the
source-built provider until SD cold-boot and reboot acceptance pass.

## Install an accepted image to eMMC

Treat eMMC installation as two separate writes: the generated image goes to
the eMMC user area, while NXP's signed boot container goes to eMMC boot
partition 1 through the ROM's USB serial downloader. The latter step removes
any dependency on a factory-installed boot container that happened to remain
in the hardware boot partition.

First boot and accept the image from SD. Keep that card unchanged as the
recovery path. From the running SD system:

1. Use `findmnt /`, `findmnt /boot`, `lsblk`, and
   `/sys/block/mmcblk*/device/type` to distinguish the mounted SD device from
   the inactive eMMC. Do not infer the target from a previously observed
   `mmcblk` number.
2. Save the eMMC user area, both hardware boot partitions
   (`mmcblkXboot0` and `mmcblkXboot1`), the partition table, sizes, and hashes
   to separate recovery storage. A backup of `mmcblkX` alone does **not**
   include the hardware boot partitions.
3. Prove that the retained SD card still boots before writing eMMC.
4. Decompress the accepted image into the independently verified, unmounted
   eMMC user-area device. Flush it, then hash exactly the image-length prefix
   read back from that device and compare it with the decompressed image.

For example, after replacing both placeholders with paths established during
the preflight:

```console
image=/path/to/nixos-frdm-imx95.img.zst
target=/dev/mmcblkX  # replace X only after completing the preflight

image_bytes="$(zstd -dc "$image" | wc -c)"
image_sha256="$(zstd -dc "$image" | sha256sum | cut -d' ' -f1)"
zstd -dc "$image" | sudo dd of="$target" bs=4M conv=fsync status=progress
sudo blockdev --flushbufs "$target"
sudo head -c "$image_bytes" "$target" | sha256sum
```

The final hash must equal `$image_sha256`. Power off after verification.
Because SD and eMMC copies use the same `BOOT` and `NIXOS_SD` identities,
remove the SD card before accepting the eMMC boot.

### Program the eMMC hardware boot partition

Use a Linux host for the tested UUU path. On macOS 26, UUU may fail to claim
the ROM device because of the open
[libusb/HID regression](https://github.com/nxp-imx/mfgtools/issues/510).

1. Build the current licensed container and resolve its output dynamically:

   ```console
   boot_output="$(
     nix build --impure -j 1 --no-link --print-out-paths \
       .#packages.aarch64-linux.nxp-imx95-boot-container
   )"
   boot_container="$boot_output/imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all"
   ```

2. With power off, connect the board's USB1/J3 port to the Linux host and
   select serial-download boot as described by NXP's board guide. After a
   complete power cycle, UUU must identify the device as `MX95` using the
   `SDPS` protocol:

   ```console
   uuu_output="$(
     nix build --impure --no-link --print-out-paths nixpkgs#uuu
   )"
   sudo "$uuu_output/bin/uuu" -lsusb
   ```

3. Program only the bootloader:

   ```console
   sudo "$uuu_output/bin/uuu" -b emmc "$boot_container"
   ```

The tested `-b emmc` flow writes boot partition 1 and selects it in eMMC
`PARTITION_CONFIG`; it does not rewrite the user area installed above. UUU
also provides an `emmc_all` workflow, but this repository has not validated
that path with the generated compressed NixOS image.

Return the switches to eMMC boot, disconnect the serial-download cable if
necessary, and power-cycle. Accept the result only after:

- the boot-container-length prefix of `mmcblkXboot0` hashes identically to the
  locally built container;
- `mmc extcsd read` reports boot partition 1 enabled;
- `/` and `/boot` resolve to the eMMC partitions and the root filesystem has
  expanded;
- all six A55 CPUs, MAC-based DHCP, and the expected NixOS generation are
  present;
- `systemctl --failed` is empty; and
- a second eMMC boot passes the same checks.

Rollback means powering off, reinserting the retained accepted SD card, and
selecting SD boot. Keep the user-area and boot-partition backups offline.

Factory restoration is a separate, reviewed operation. Boot the accepted SD,
repeat the device-identity preflight, and verify every saved artifact before
writing anything. Restore the user-area image only to the inactive eMMC user
area. Restore `boot0` and `boot1` to their matching hardware partitions,
temporarily clearing each partition's `force_ro` sysfs control only for its
write and restoring it immediately afterward. Reapply the saved eMMC boot
configuration if it differs, then perform length-limited readback hashes of
all three areas before selecting eMMC boot. Neither the backups nor licensed
NXP artifacts may be published.

## Consumer modules

```nix
{
  hardware.nxp.imx95.bootContainer =
    inputs.nixos-imx95.packages.${pkgs.system}.frdm-imx95-source-boot-container;

  imports = [
    inputs.nixos-imx95.nixosModules.frdm-imx95-core
    inputs.nixos-imx95.nixosModules.frdm-imx95-sd-image
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "frdm-imx95-source-boot-container"
      "imx-boot-imx95"
      "lpddr4x_dmem_qb_v202409.bin"
      "lpddr4x_dmem_v202409.bin"
      "lpddr4x_imem_qb_v202409.bin"
      "lpddr4x_imem_v202409.bin"
      "mx95b0-ahab-container.img"
      "nxp-imx95-boot-container"
      "nxp-imx95-ele-firmware"
      "nxp-imx95-lpddr4x-dmem"
      "nxp-imx95-lpddr4x-dmem-qb"
      "nxp-imx95-lpddr4x-imem"
      "nxp-imx95-lpddr4x-imem-qb"
      "nixos-frdm-imx95.img.zst"
      "nixos-frdm-imx95-source-built.img.zst"
    ];
}
```

The core module selects a mainline kernel with upstream FRDM support, uses the
exact upstream DTB, enables extlinux, and configures the A55 console on
`ttyLP0`. The SD-image module owns only the licensed boot-container boundary
and deterministic image layout. Omit the explicit `bootContainer` assignment
to select the complete-container compatibility provider.

## Source pointers

- NXP U-Boot FRDM configuration:
  [`imx95_15x15_frdm_defconfig`](https://github.com/nxp-imx/uboot-imx/blob/6eeef838dac4ddbc06ff14450531a95e8c5cb346/configs/imx95_15x15_frdm_defconfig)
- Authoritative LF6.18.20 FRDM machine mapping:
  [`imx95-15x15-lpddr4x-frdm.conf`](https://github.com/nxp-imx/meta-imx/blob/5bde00498b041167629890563478eb89c7ca10b8/meta-imx-bsp/conf/machine/imx95-15x15-lpddr4x-frdm.conf)
- Local immutable release mapping:
  [`packages/imx95-lf-6.18.20-2.0.0.nix`](packages/imx95-lf-6.18.20-2.0.0.nix)
- Release WIC layout:
  [`imx-imx-boot-bootpart.wks.in`](https://github.com/Freescale/meta-freescale/blob/2781242e499e601ef9454009aceed16186a48d9e/wic/imx-imx-boot-bootpart.wks.in)
- Board guide:
  [Getting Started with FRDM-i.MX95](https://www.nxp.com/document/guide/getting-started-with-frdm-imx95:GS-FRDM-IMX95)
