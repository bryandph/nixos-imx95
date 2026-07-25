{lib, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") (
      let
        kernel = pkgs.callPackage ../packages/linux-imx95-all-features.nix {};
      in {
        packages.linux-imx95-all-features = kernel;

        checks.all-features-kernel =
          pkgs.runCommand "frdm-imx95-all-features-kernel" {
            nativeBuildInputs = [
              pkgs.dtc
              pkgs.jq
            ];
          } ''
            configFile=${kernel.configfile}
            modulesBuiltin=${kernel.modules}/lib/modules/${kernel.modDirVersion}/modules.builtin
            modulesOrder=${kernel.modules}/lib/modules/${kernel.modDirVersion}/modules.order
            dtb=${kernel}/dtbs/${kernel.combinedDtb}

            grep -q '^CONFIG_DRM_PANTHOR=m$' "$configFile"
            grep -q '^# CONFIG_MALI_MIDGARD is not set$' "$configFile"
            grep -q '^CONFIG_VIDEO_IMX8_JPEG=m$' "$configFile"
            grep -q '^CONFIG_IMX_REMOTEPROC=y$' "$configFile"
            grep -q '^CONFIG_IMX_NEUTRON_REMOTEPROC=y$' "$configFile"
            grep -q '^CONFIG_NEUTRON=y$' "$configFile"
            grep -q '^CONFIG_NETFILTER_XT_MATCH_COMMENT=m$' "$configFile"
            grep -q '^CONFIG_NETFILTER_XT_MATCH_PKTTYPE=m$' "$configFile"
            grep -q '^CONFIG_MXC_MUR=y$' "$configFile"
            grep -q '^CONFIG_MXC_VIDEO_WAVE6_CTRL=y$' "$configFile"
            grep -q '^CONFIG_MXC_VIDEO_WAVE6=y$' "$configFile"

            grep -q 'drivers/remoteproc/imx_rproc.ko' "$modulesBuiltin"
            grep -q 'drivers/remoteproc/imx_neutron_rproc.ko' "$modulesBuiltin"
            grep -q 'drivers/staging/neutron/neutron.ko' "$modulesBuiltin"
            grep -q 'drivers/mxc/vpu/wave6/wave6-vpu-ctrl.ko' "$modulesBuiltin"
            grep -q 'drivers/mxc/vpu/wave6/wave6.ko' "$modulesBuiltin"
            grep -q 'drivers/mmc/core/mmc_block.ko' "$modulesBuiltin"
            grep -q 'drivers/mmc/host/sdhci.ko' "$modulesBuiltin"
            grep -q 'drivers/mmc/host/sdhci-esdhc-imx.ko' "$modulesBuiltin"
            grep -q 'drivers/gpu/drm/panthor/panthor.ko' "$modulesOrder"
            grep -q 'drivers/media/platform/nxp/imx-jpeg/mxc-jpeg-encdec.ko' "$modulesOrder"
            grep -q 'net/netfilter/xt_comment.ko' "$modulesOrder"
            grep -q 'net/netfilter/xt_pkttype.ko' "$modulesOrder"
            if grep -q 'drivers/gpu/arm/midgard/mali_kbase.ko' "$modulesOrder"; then
              echo "combined kernel unexpectedly contains the NXP kbase module" >&2
              exit 1
            fi

            test -f "$dtb"
            dtc -I dtb -O dts "$dtb" > combined.dts
            grep -q 'compatible = "fsl,imx95-cm7"' combined.dts
            grep -q 'compatible = "fsl,cnm633c-vpu"' combined.dts
            grep -q 'compatible = "fsl,cm633c-vpu-ctrl"' combined.dts
            grep -q 'compatible = "fsl,imx95-neutron"' combined.dts
            grep -q 'compatible = "fsl,imx95-neutron-rproc"' combined.dts

            mkdir -p "$out"
            ${lib.getExe pkgs.bash} ${../scripts/check-imx95-neutron-dtb} \
              "$dtb" "$out/neutron-resources.json"
            jq -e \
              '.reservedBytes == 4294967296 and
               .expectedLinuxVisibleDeltaBytes == 4294967296 and
               (.compiledMemoryContainsPool or
                .bootloaderMemoryFixupRequired)' \
              "$out/neutron-resources.json" >/dev/null
          '';
      }
    );
}
