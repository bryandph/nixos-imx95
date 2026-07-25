{
  buildLinux,
  fetchFromGitHub,
  lib,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  source = release.neutron.kernel.nxpReference;
  wave6Delta = release.multimedia.wave6.kernelDelta;
  kernelSource = fetchFromGitHub source.fetchFromGitHub;
  kernel = buildLinux {
    pname = "linux-imx95-all-features";
    version = "6.18.20";
    modDirVersion = "6.18.20";

    src = kernelSource;
    features = {};
    defconfig = "imx_v8_defconfig";
    enableCommonConfig = false;
    autoModules = false;
    structuredExtraConfig = with lib.kernel; {
      ARCH_MXC = yes;

      DRM = yes;
      DRM_PANTHOR = module;
      MALI_MIDGARD = no;

      MEDIA_SUPPORT = yes;
      VIDEO_DEV = yes;
      V4L_MEM2MEM_DRIVERS = yes;
      VIDEO_IMX8_JPEG = module;

      REMOTEPROC = yes;
      IMX_REMOTEPROC = yes;
      IMX_NEUTRON_REMOTEPROC = yes;
      NEUTRON = yes;
      DEBUG_FS = yes;

      NETFILTER_XT_MATCH_COMMENT = module;
      NETFILTER_XT_MATCH_PKTTYPE = module;

      MXC_MUR = yes;
      MXC_VIDEO_WAVE6_CTRL = yes;
      MXC_VIDEO_WAVE6 = yes;
    };
    ignoreConfigErrors = false;

    extraPassthru = {
      providerKind = "nxp-full-combined";
      capabilities = [
        "gpu-panthor"
        "jpeg"
        "m7-remoteproc"
        "neutron"
        "wave6"
      ];
      releaseMapping = release;
      provenance = {
        repository = source.repository;
        branch = source.branch;
        rev = source.rev;
        neutronDelta = release.neutron.kernel.delta;
        inherit wave6Delta;
      };
      kernelOverride = kernel.override;
      combinedDtb = "freescale/imx95-15x15-frdm-neutron.dtb";
      m7Dtb = kernel.combinedDtb;
      neutronDtb = kernel.combinedDtb;
      wave6Dtb = kernel.combinedDtb;
      neutronUapi = "${kernelSource}/drivers/staging/neutron/uapi/neutron.h";
    };

    extraMeta = {
      description = "Release-pinned NXP i.MX95 kernel for the composed FRDM feature set";
      homepage = source.repository;
      license = source.license;
      platforms = ["aarch64-linux"];
    };
  };
in
  kernel
