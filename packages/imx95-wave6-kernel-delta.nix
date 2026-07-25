{
  providerSelection = {
    selected = "full-nxp-reference";
    reducedCandidate = {
      status = "rejected-source-dependency-audit";
      rationale = ''
        Linux 7.1 has the i.MX95 VPU clocks, power-domain identifiers,
        VPU block controller, SRAM, and FRDM reserved boot memory, but it has
        no Wave6 driver or binding. The release-pinned implementation is a
        21-file, 14,307-line driver subtree with a separate NXP-only memory
        usage recorder and an undocumented controller/device-tree ABI.
        Copying those vendor subsystems wholesale would be a second full
        provider, not a finite reduced patch whose semantics can be reviewed
        independently. Keep the full pinned NXP provider selected; do not
        silently fall back at run time.
      '';
      rejectionEvidence = {
        nxpOnly = [
          "drivers/mxc/vpu/wave6 (21 files, 14307 lines)"
          "drivers/mxc/vpu/memory_usage"
          "include/linux/imx_memory_usage.h"
          "fsl,cnm633c-vpu and fsl,cm633c-vpu-ctrl device-tree ABI"
          "cnm,ctrl, boot, sram, and support-follower properties"
        ];
        upstreamNonEquivalent = [
          "drivers/media/platform/chips-media/wave5"
          "Documentation/devicetree/bindings/media/cnm,wave521c.yaml"
        ];
        upstreamAvailable = [
          "arch/arm64/boot/dts/freescale/imx95-power.h"
          "include/dt-bindings/clock/nxp,imx95-clock.h"
          "arch/arm64/boot/dts/freescale/imx95.dtsi: vpu_blk_ctrl and sram1"
          "arch/arm64/boot/dts/freescale/imx95-15x15-frdm.dts: vpu_boot"
        ];
      };
      missingEvidence = [
        "reduced-device-tree-bind"
        "h264-hardware-round-trip"
        "h265-hardware-round-trip"
      ];
    };
  };

  kernel = {
    sourceAuthority = "neutron.kernel.nxpReference";
    requiredConfig = [
      "ARCH_MXC"
      "MEDIA_SUPPORT"
      "VIDEO_DEV"
      "V4L_MEM2MEM_DRIVERS"
      "MXC_MUR"
      "MXC_VIDEO_WAVE6_CTRL"
      "MXC_VIDEO_WAVE6"
    ];
    sourcePaths = [
      "drivers/mxc/vpu/Kconfig"
      "drivers/mxc/vpu/Makefile"
      "drivers/mxc/vpu/memory_usage"
      "drivers/mxc/vpu/wave6"
      "include/linux/imx_memory_usage.h"
    ];
  };

  deviceTree = {
    boardPath = "arch/arm64/boot/dts/freescale/imx95-15x15-frdm.dts";
    socPath = "arch/arm64/boot/dts/freescale/imx95.dtsi";
    selectedDtb = "freescale/imx95-15x15-frdm.dtb";
    requiredLabels = [
      "vpu0"
      "vpuctrl"
    ];
    compatible = "fsl,cnm633c-vpu";
    controllerCompatible = "fsl,cm633c-vpu-ctrl";
    bindingStatus = "absent-from-nxp-and-upstream-trees";
  };
}
