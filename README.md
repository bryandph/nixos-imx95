# nixos-imx95

Reusable NixOS support for NXP i.MX 95 boards. The first supported target is
the NXP FRDM-i.MX95.

The flake builds U-Boot, TF-A, OP-TEE, System Manager, OEI, and imx-mkimage
from release-pinned source. Only NXP's ELE firmware and four Synopsys
LPDDR4X training binaries remain operator-supplied. Those components are
assembled with imx-mkimage's `flash_a55` target, which retains the M33
System Manager but omits NXP's unrelated prebuilt M7 demonstration.

The physically accepted source-built provider is the module default. The
previous complete-container provider remains available explicitly for
compatibility and recovery. Both paths boot a mainline NixOS kernel and the
upstream `freescale/imx95-15x15-frdm.dtb` through extlinux. Builds never
modify a device.

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
  .#packages.aarch64-linux.frdm-imx95-sd-image
```

`frdm-imx95-sd-image` uses the accepted source-built provider.
`frdm-imx95-source-built-sd-image` remains as a descriptive alias, while
`frdm-imx95-compatibility-sd-image` selects the complete NXP container for
recovery. The checks parse the source-built AHAB inventory, reject
missing/corrupt/unsafe inputs, compare two clean assemblies byte-for-byte, and
verify both providers' exact bytes at the raw SD offset.

## Optional mainline GPU and JPEG evaluation

The exported `frdm-imx95-multimedia` module is opt-in. It retains the board
core's upstream kernel, enables the open Mesa graphics stack, installs
hardware-evidencing GPU and JPEG probes, and defines standard `video` group
access for the V4L2 JPEG devices. It does not enable a display server,
desktop, camera, or NXP binary GPU userspace, and it is not imported by the
default board configuration.

```nix
{
  imports = [
    inputs.nixos-imx95.nixosModules.frdm-imx95-core
    inputs.nixos-imx95.nixosModules.frdm-imx95-sd-image
    inputs.nixos-imx95.nixosModules.frdm-imx95-multimedia
  ];

  users.users.<operator>.extraGroups = ["video"];
}
```

On a physical board, run the probes as the non-root operator:

```console
frdm-imx95-gpu-smoke
frdm-imx95-jpeg-smoke
```

The GPU command creates a surfaceless EGL/GLES context, submits a deterministic
shader draw, validates pixel readback, rejects software renderers, and confirms
that Vulkan enumerates the Mali device through PanVK. The JPEG command
discovers encoder and decoder roles by V4L2 driver and formats, then performs a
generated BGR3 → JPEG → BGR3 hardware round trip. Both write JSON reports and
remove temporary files on every exit. The release mapping under
`packages/imx95-lf-6.18.20-2.0.0.nix` is the authority for expected drivers,
interfaces, and provenance.

## Optional NXP Wave6 VPU evaluation

Wave6 is not present in the accepted upstream kernel. The separate exported
`frdm-imx95-wave6-vpu` module selects the full release-pinned NXP kernel and
matching FRDM device tree explicitly. A reduced backport remains rejected by
the evidence gate until it builds, binds the physical VPU, and passes both
codec paths with every NXP-only dependency accounted for. Mainline GPU results
must not be attributed to this separate kernel target without rerunning them;
the composed all-features role below installs those probes for that purpose.

The Wave6 driver uses standard V4L2 mem2mem userspace, but its
`wave633c_codec_fw.bin` firmware member comes from NXP's licensed
`firmware-imx-8.32-1991416.bin` distribution. Review and accept that license,
then import the fixed distribution locally:

```console
./scripts/import-nxp-wave6-firmware --accept-license \
  /path/to/firmware-imx-8.32-1991416.bin
```

Because the selected member's standalone hash and size are not yet available,
the import helper adds the complete hash-pinned distribution to the local Nix
store as a build source. This is intentional: using only an extracted member
would otherwise discard the fixed identity or require inventing one. The
firmware package extracts only the release-recipe-selected member into its
output and retains no store-path reference to the source distribution, so the
runtime, system, and image closures contain only that member package. The
complete distribution remains local build input and must not be copied with
the output closure.

Never publish the distribution, firmware output, dependent closure, generated
image, or hardware report containing licensed bytes.

Compose the VPU role only in a dedicated removable-media evaluation:

```nix
{
  imports = [
    inputs.nixos-imx95.nixosModules.frdm-imx95-core
    inputs.nixos-imx95.nixosModules.frdm-imx95-sd-image
    inputs.nixos-imx95.nixosModules.frdm-imx95-wave6-vpu
  ];

  users.users.<operator>.extraGroups = ["video"];
}
```

After confirming the kernel, device-tree, firmware, and `wave6` device
bindings, run:

```console
frdm-imx95-wave6-smoke
```

The command discovers Wave6 encoder and decoder roles and performs generated
H.264 and H.265 V4L2 round trips. It fails if no identified Wave6 hardware path
participates. Validate the feature image only from independently identified
removable media, without writing eMMC or persistent boot-selection state.
Rollback is powering off, removing the evaluation medium, and booting the
untouched known-good installed/eMMC fleet system.

## Optional Neutron NPU evaluation

The exported `frdm-imx95-neutron-npu` module is an evaluation role, not part of
the default FRDM core or image. It selects the evidence-approved Neutron kernel
provider and reviewed device tree, then adds the locally imported runtime,
operator-supplied converted model, least-privilege device access, and bounded
smoke interface. The accepted boot container is unchanged.

Treat `packages/imx95-lf-6.18.20-2.0.0.nix` as the authority for source
pointers, immutable identities, member paths, license authorities, and the
release-label reconciliation. Do not copy proprietary runtime, converter, or
converted-model bytes into this checkout or a public cache.

### Import the runtime and convert the smoke model

After reviewing the licenses referenced by the release mapping, check out the
pinned Neutron source locally and import only the selected members:

```console
nix run --impure .#import-imx95-neutron-runtime -- \
  --accept-license /path/to/pinned-neutron-checkout
```

The command verifies the license, content register, SBOM, firmware, userspace
library, and required headers before adding the four runtime members
individually to the local Nix store under their release-pinned names and
SHA-256 identities. No runtime path needs to be passed to later evaluations.

Run model conversion on an `x86_64-linux` host. Point the impure evaluation at
the exact operator-downloaded Python 3.11 wheel:

```console
export NIXOS_IMX95_NEUTRON_CONVERTER_WHEEL=\
/path/to/eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl
converter_root="$(
  nix build --impure -j 1 --no-link --print-out-paths \
    .#packages.x86_64-linux.eiq-neutron-sdk
)"
model_root="$(
  nix build --impure -j 1 --no-link --print-out-paths \
    .#packages.x86_64-linux.imx95-neutron-model-source
)"
nix run --impure .#convert-imx95-neutron-model -- \
  --accept-license \
  "$NIXOS_IMX95_NEUTRON_CONVERTER_WHEEL" \
  "$converter_root/bin/neutron_converter" \
  "$model_root/share/models/mobilenet_v1_1.0_224_quant.tflite" \
  946a912f68b1d8d85ce33911287cdc3eedaf4cdbd1b102d7ba0c125c65a0e9ba
unset NIXOS_IMX95_NEUTRON_CONVERTER_WHEEL
```

The derivation verifies the wheel and source-model identities, runs two
conversions with `--force-determinism`, rejects differing results, asserts the
converted identity pinned in the release mapping, and imports the verified
model under its pinned file name. Keep the resulting path local unless
affirmative redistribution authority is established.

Compose the module only in a dedicated evaluation configuration:

```nix
{
  imports = [
    inputs.nixos-imx95.nixosModules.frdm-imx95-core
    inputs.nixos-imx95.nixosModules.frdm-imx95-sd-image
    inputs.nixos-imx95.nixosModules.frdm-imx95-neutron-npu
  ];

  users.users.<operator>.extraGroups = ["neutron"];
}
```

Aggregate systems and images inherit the unfree, non-redistributable,
local-build-preferred, substitute-disabled, and Hydra-disabled policy.

### Capture and accept the evaluation

After importing the four runtime members and converted model, build the
dedicated image without any licensed-input environment variables:

```console
nix build --impure -j 1 \
  .#packages.aarch64-linux.frdm-imx95-neutron-npu-sd-image
```

The configuration and image output are always present. If any licensed member
is absent, its `requireFile` boundary fails closed with the exact local import
procedure. The bytes remain operator-supplied and must not be published.

Identify the removable target independently with `findmnt`, `lsblk`, and the
MMC sysfs device type; never infer it from a previous `mmcblk` number. Write
only that unmounted SD medium. Do not write the eMMC user area, either eMMC
hardware boot partition, or persistent boot-selection state.

Capture both the A55 console (`ttyLP0`) and the M33/System Manager UART from
power-on. After a cold boot, collect at least:

```console
uname -a
nproc
cat /sys/devices/system/cpu/online
findmnt /
findmnt /boot
systemctl --failed
journalctl -b -k
ls -l /dev/neutron0
```

Verify six online A55 CPUs, the expected memory delta from the reusable Neutron
DMA pool, SCMI, OP-TEE, Ethernet/SSH, root and boot-medium identity, the
selected kernel/device tree, firmware loading, and no unexpected failed units.

Run the negative control and accelerator proof as the authorized non-root
operator:

```console
frdm-imx95-neutron-smoke --cpu-only
frdm-imx95-neutron-smoke
```

The CPU run must explicitly report non-acceptance. The Neutron run is accepted
only when its JSON report records the declared five-byte maximum quantized
output delta, the same top output, a nonzero delegated-node count, and movement
in the independent Neutron debugfs performance counters. The smoke wrapper uses
the dynamically linked compatibility benchmark from
`packages/imx95-neutron-benchmark.cc` so the executable and external delegate
share one TensorFlow Lite runtime. A successful benchmark exit or CPU fallback
is not accelerator evidence. Confirm separately that a user outside the
`neutron` group cannot open the device. Repeat the complete invariant and smoke
procedure after a second cold boot.

On failure, preserve the two UART logs, smoke JSON, `journalctl -b -k`,
`systemctl --failed`, mount identity, CPU/memory state, device permissions, and
hashes or store paths of selected inputs. Never attach proprietary bytes or
decoded content to an issue. Power off, remove the evaluation SD, boot the
untouched known-good installed/eMMC fleet system, and re-run its normal
invariants. Rollback requires no repair because the evaluation procedure does
not write eMMC or persistent boot-selection state.

## Combined FRDM feature evaluation

The exported `frdm-imx95-all-features` module is the combined kernel and
device-tree provider for a configuration that explicitly composes M7
remoteproc, the open Mesa GPU and V4L2 JPEG probes, Wave6 VPU, and Neutron NPU.
It selects the single `linux-imx95-all-features` package built from the pinned
NXP 6.18.20 source. That source already carries the FRDM M7 node, the Wave6 and
Neutron devices, and the Neutron reserved-memory overlay, so the mainline M7
overlay is intentionally suppressed in this composition. The provider does
not import the feature roles itself, preventing duplicate imports in parent
fleet compositions. The default core and each standalone evaluation role
remain separate and buildable.

```nix
{
  imports = [
    inputs.nixos-imx95.nixosModules.frdm-imx95-core
    inputs.nixos-imx95.nixosModules.frdm-imx95-sd-image
    inputs.nixos-imx95.nixosModules.frdm-imx95-all-features
    inputs.nixos-imx95.nixosModules.frdm-imx95-m7-remoteproc
    inputs.nixos-imx95.nixosModules.frdm-imx95-multimedia
    inputs.nixos-imx95.nixosModules.frdm-imx95-neutron-npu
    inputs.nixos-imx95.nixosModules.frdm-imx95-wave6-vpu
  ];

  users.users.<operator>.extraGroups = [
    "neutron"
    "video"
  ];
}
```

The Wave6 firmware and Neutron runtime/model boundaries remain unfree,
non-redistributable, local-build preferred, substitute-disabled, and excluded
from Hydra. Never publish the composed closure, SD image, imported source
distribution, converted model, or a hardware report containing licensed
bytes. The image output is
`packages.aarch64-linux.frdm-imx95-all-features-sd-image`.
Validate this feature image only from removable media. Do not write eMMC or
persistent boot-selection state; rollback is booting the untouched known-good
installed/eMMC fleet system.

## Optional M7 remoteproc development

The exported `frdm-imx95-m7-remoteproc` NixOS module adds the upstream
`fsl,imx95-cm7` remoteproc node to the mainline FRDM device tree. It is not
part of the default board composition, does not install or auto-start
firmware, and does not add an M7 payload to the boot container. When composed
through `frdm-imx95-all-features`, the reviewed NXP device tree supplies that
node directly and the module does not apply its mainline overlay.

The first public firmware target is the original MIT-licensed Embassy-Rust
application under `firmware/frdm-imx95-m7-smoke`, exposed as the
`frdm-imx95-m7-smoke` package and built as a remoteproc-loadable Cortex-M7
ELF. NXP's release archive contains only a raw, licensed power-mode
demonstration binary; its identity and the corresponding public BSD-3-Clause
MCUXpresso source pointers are recorded in
`packages/imx95-lf-6.18.20-2.0.0.nix`. Operators can import the pinned member
locally with `scripts/import-nxp-m7-power-mode-demo` and build
`nxp-imx95-m7-power-mode-demo`. The unfree package is local-build preferred,
substitute-disabled, absent from public checks, and installs the raw binary
outside `lib/firmware` because Linux remoteproc requires ELF. No NXP demo
artifact enters this repository or its public build.

The Embassy demo executes M7-local wait-for-interrupt after every heartbeat,
with SysTick as its bounded wake source. Linux/SRTM coordination, System
Manager authorization, an A55 wake source, and recovery preconditions have
not been validated, so the public firmware exposes no A55 power command and
A55 control remains disabled.

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
NXP U-Boot. A systemd generator derives `/boot` partition 1 from the physical
MMC device hosting `/`, so duplicate labels and UUIDs on simultaneously
attached SD and eMMC media cannot redirect later NixOS generations to the
wrong extlinux filesystem. The ext4 root uses the stable `NIXOS_SD` identity
and expands on first boot by resolving its kernel major/minor identity through
sysfs rather than assuming a device-node minor number.

No flashing app is provided. These outputs are generic board and evaluation
artifacts: they do not carry fleet identity, operator SSH keys, or secrets.
Feature acceptance uses removable media only and leaves the installed/eMMC
fleet system untouched for rollback. The complete-container provider remains
available if source assembly needs to be ruled out during diagnosis.

## Optional generic board installation to eMMC

This destructive procedure is for deliberate generic board provisioning, not
feature-image acceptance or fleet rollout. Fleet identity, SSH authorization,
and secrets belong to the consuming fleet configuration and are not provided
by this repository. Feature evaluations must not use this procedure.

Treat eMMC installation as two separate writes: the generated image goes to
the eMMC user area, while NXP's signed boot container goes to eMMC boot
partition 1 through the ROM's USB serial downloader. The latter step removes
any dependency on a factory-installed boot container that happened to remain
in the hardware boot partition.

First boot and accept the generic image from an independently identified SD
card. Establish verified offline backups and a reviewed out-of-band recovery
path before changing eMMC. From the running SD system:

1. Use `findmnt /`, `findmnt /boot`, `lsblk`, and
   `/sys/block/mmcblk*/device/type` to distinguish the mounted SD device from
   the inactive eMMC. Do not infer the target from a previously observed
   `mmcblk` number.
2. Save the eMMC user area, both hardware boot partitions
   (`mmcblkXboot0` and `mmcblkXboot1`), the partition table, sizes, and hashes
   to separate recovery storage. A backup of `mmcblkX` alone does **not**
   include the hardware boot partitions.
3. Prove the recovery environment and saved-artifact inventory before writing
   eMMC.
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
       .#packages.aarch64-linux.frdm-imx95-source-boot-container
   )"
   boot_container="$boot_output/imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55"
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

For feature validation, rollback is instead powering off, removing the
evaluation SD, and booting the untouched known-good installed/eMMC fleet
system. Recovery from this optional destructive provisioning workflow uses the
verified offline user-area and boot-partition backups.

Factory restoration is a separate, reviewed operation. Boot an independently
verified recovery environment, repeat the device-identity preflight, and
verify every saved artifact before writing anything. Restore the user-area
image only to the inactive eMMC user area. Restore `boot0` and `boot1` to their
matching hardware partitions, temporarily clearing each partition's
`force_ro` sysfs control only for its write and restoring it immediately
afterward. Reapply the saved eMMC boot configuration if it differs, then
perform length-limited readback hashes of all three areas before selecting
eMMC boot. Neither the backups nor licensed NXP artifacts may be published.

## Consumer modules

```nix
{
  imports = [
    inputs.nixos-imx95.nixosModules.frdm-imx95-core
    inputs.nixos-imx95.nixosModules.frdm-imx95-sd-image
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "frdm-imx95-source-boot-container"
      "imx-boot-imx95"
      "imx95"
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
      "nxp-imx95-m7-power-mode-demo"
      "nixos-frdm-imx95-compatibility.img.zst"
      "nixos-frdm-imx95.img.zst"
      "nixos-frdm-imx95-source-built.img.zst"
    ];
}
```

The core module selects a mainline kernel with upstream FRDM support, uses the
exact upstream DTB, enables extlinux, and configures the A55 console on
`ttyLP0`. The SD-image module owns only the licensed boot-container boundary
and deterministic image layout. Its default is the source-built provider. To
recover with the complete-container provider, set
`hardware.nxp.imx95.bootContainer` to
`inputs.nixos-imx95.packages.${pkgs.system}.nxp-imx95-boot-container`
explicitly.

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
