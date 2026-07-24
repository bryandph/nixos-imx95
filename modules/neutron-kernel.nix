{lib, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") (
      let
        release = import ../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
        referenceKernel = pkgs.callPackage ../packages/linux-imx95-neutron.nix {};
        reducedKernel = pkgs.callPackage ../packages/linux-imx95-neutron-reduced.nix {};
        inventoryJson = pkgs.writeText "imx95-neutron-kernel-delta.json" (
          builtins.toJSON release.neutron.kernel.delta
        );
        checkProvider = provider:
          pkgs.runCommand "frdm-imx95-neutron-${provider.providerKind}" {
            nativeBuildInputs = [
              pkgs.dtc
              pkgs.gitMinimal
              pkgs.jq
            ];
          } ''
            configFile=${provider.configfile}
            modulesBuiltin=${provider.modules}/lib/modules/${provider.modDirVersion}/modules.builtin
            dtb=${provider}/dtbs/${provider.neutronDtb}

            grep -q '^CONFIG_NEUTRON=y$' "$configFile"
            grep -q '^CONFIG_IMX_NEUTRON_REMOTEPROC=y$' "$configFile"
            grep -q '^CONFIG_REMOTEPROC=y$' "$configFile"
            grep -q 'drivers/staging/neutron/neutron.ko' "$modulesBuiltin"
            grep -q 'drivers/remoteproc/imx_neutron_rproc.ko' "$modulesBuiltin"

            test "$(git hash-object ${provider.neutronUapi})" = \
              285ade234acfdfafe9164992f871593e7fadf236
            test -f "$dtb"

            mkdir -p "$out"
            ${lib.getExe pkgs.bash} ${../scripts/check-imx95-neutron-dtb} \
              "$dtb" "$out/resources.json"
            jq -e \
              '.reservedBytes == 4294967296 and
               .expectedLinuxVisibleDeltaBytes == 4294967296 and
               (.compiledMemoryContainsPool or
                .bootloaderMemoryFixupRequired)' \
              "$out/resources.json" >/dev/null
            cp ${inventoryJson} "$out/delta.json"
          '';
      in {
        packages = {
          inherit referenceKernel reducedKernel;
          linux-imx95-neutron = referenceKernel;
          linux-imx95-neutron-reduced = reducedKernel;
          linux-imx95-neutron-reduced-patch = reducedKernel.neutronPatch;
        };

        checks = {
          neutron-kernel-delta-inventory =
            pkgs.runCommand "frdm-imx95-neutron-kernel-delta-inventory" {
              nativeBuildInputs = [pkgs.jq];
            } ''
              jq -e '
                .schemaVersion == 1 and
                (.fileDelta.added | length) == 14 and
                (.fileDelta.modified | length) == 7 and
                .kernelConfig.required.NEUTRON == "y" and
                .kernelConfig.required.IMX_NEUTRON_REMOTEPROC == "y" and
                .deviceTree.resources.reservedMemory.address == "0x100000000" and
                .deviceTree.resources.reservedMemory.size == "0x100000000" and
                .deviceTree.resources.accelerator.interrupt.number == 318 and
                .deviceTree.resources.accelerator.iommu.streamId == "0xd"
              ' ${inventoryJson} >/dev/null
              cp ${inventoryJson} "$out"
            '';
          neutron-kernel-reference = checkProvider referenceKernel;
          neutron-kernel-reduced = checkProvider reducedKernel;
        };
      }
    );
}
