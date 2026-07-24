{
  features ? null,
  lib,
  linuxPackages_latest,
  buildLinux,
  callPackage,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  patch = callPackage ./linux-imx95-neutron-reduced-patch.nix {};
  baseKernel = linuxPackages_latest.kernel;

  kernel = buildLinux {
    pname = "linux-imx95-neutron-reduced";
    inherit (baseKernel) src version modDirVersion;
    defconfig = "defconfig";
    features =
      if features == null
      then baseKernel.features
      else features;
    kernelPatches =
      baseKernel.kernelPatches
      ++ [
        {
          name = "imx95-neutron-reviewed-delta";
          inherit patch;
        }
      ];
    structuredExtraConfig = with lib.kernel; {
      ARCH_MXC = yes;
      DEBUG_FS = yes;
      REMOTEPROC = yes;
      IMX_NEUTRON_REMOTEPROC = yes;
      NEUTRON = yes;
    };
    ignoreConfigErrors = false;
    extraPassthru = {
      providerKind = "reduced-mainline";
      releaseMapping = release;
      provenance = {
        upstream = release.neutron.kernel.upstreamComparison;
        nxpReference = release.neutron.kernel.nxpReference;
        delta = release.neutron.kernel.delta;
      };
      kernelOverride = kernel.override;
      neutronPatch = patch;
      neutronDtb = "freescale/imx95-15x15-frdm-neutron.dtb";
      neutronUapi = "${patch.nxpSource}/drivers/staging/neutron/uapi/neutron.h";
    };
    extraMeta = {
      description = "Mainline arm64 kernel with the reviewed i.MX95 Neutron delta";
    };
  };
in
  kernel
