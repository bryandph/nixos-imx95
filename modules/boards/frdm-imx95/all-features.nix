{
  inputs,
  lib,
  ...
}: {
  flake.modules.nixos.frdm-imx95-all-features = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    kernel = inputs.self.packages.${system}.linux-imx95-all-features;
    nixosKernel =
      kernel
      // {
        override = override:
          kernel.kernelOverride (
            if builtins.isFunction override
            then
              override {
                features = kernel.features;
                kernelPatches = kernel.kernelPatches;
                randstructSeed = "";
              }
            else override
          );
      };
    deviceTreePackage = pkgs.runCommand "frdm-imx95-all-features-device-tree" {} ''
      install -Dm0444 \
        ${kernel}/dtbs/${kernel.combinedDtb} \
        "$out/freescale/imx95-15x15-frdm.dtb"
    '';
  in {
    boot = {
      kernelPackages = lib.mkOverride 40 (pkgs.linuxPackagesFor nixosKernel);
      initrd.availableKernelModules = lib.mkForce [
        "mmc_block"
        "sdhci"
        "sdhci-esdhc-imx"
      ];
      initrd.kernelModules = lib.mkForce [];
    };
    hardware.deviceTree.package = lib.mkOverride 40 deviceTreePackage;

    system.build = {
      allFeaturesKernel = kernel;
      deviceTreePackage = lib.mkOverride 40 deviceTreePackage;
      smoke = lib.mkOverride 40 config.system.build.neutronSmoke;
    };

    assertions = [
      {
        assertion = config.boot.kernelPackages.kernel.providerKind == "nxp-full-combined";
        message = "The all-features role must have one reviewed combined NXP kernel owner.";
      }
      {
        assertion =
          config.boot.initrd.availableKernelModules
          == [
            "mmc_block"
            "sdhci"
            "sdhci-esdhc-imx"
          ];
        message = "The combined NXP initrd must request only the FRDM SD boot modules.";
      }
      {
        assertion = config.boot.initrd.kernelModules == [];
        message = "The direct SD/ext4 root must not pull generic device-mapper initrd modules.";
      }
      {
        assertion =
          builtins.all
          (capability: builtins.elem capability kernel.capabilities)
          [
            "gpu-panthor"
            "jpeg"
            "m7-remoteproc"
            "neutron"
            "wave6"
          ];
        message = "The combined NXP kernel must declare every composed hardware capability.";
      }
      {
        assertion =
          builtins.all
          (overlay: overlay.name != "frdm-imx95-m7-remoteproc")
          config.hardware.deviceTree.overlays;
        message = "The combined NXP DT already owns the M7 node and must not apply the mainline overlay.";
      }
      {
        assertion = config.system.build.runtime.allowSubstitutes == false;
        message = "The combined role must keep the licensed Neutron runtime local-only.";
      }
      {
        assertion = config.system.build.firmware.allowSubstitutes == false;
        message = "The combined role must keep Wave6 firmware out of substitutes.";
      }
    ];
  };
}
