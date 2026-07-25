{
  buildLinux,
  fetchFromGitHub,
  lib,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  source = release.neutron.kernel.nxpReference;
  delta = release.multimedia.wave6.kernelDelta;
  kernelSource = fetchFromGitHub source.fetchFromGitHub;
  kernel = buildLinux {
    pname = "linux-imx95-wave6";
    version = "6.18.20";
    modDirVersion = "6.18.20";

    src = kernelSource;
    features = {};
    defconfig = "imx_v8_defconfig";
    enableCommonConfig = false;
    autoModules = false;
    structuredExtraConfig = with lib.kernel; {
      ARCH_MXC = yes;
      MEDIA_SUPPORT = yes;
      VIDEO_DEV = yes;
      V4L_MEM2MEM_DRIVERS = yes;
      MXC_MUR = yes;
      MXC_VIDEO_WAVE6_CTRL = yes;
      MXC_VIDEO_WAVE6 = yes;
    };
    ignoreConfigErrors = false;

    extraPassthru = {
      providerKind = delta.providerSelection.selected;
      releaseMapping = release;
      provenance = {
        repository = source.repository;
        branch = source.branch;
        rev = source.rev;
        inherit delta;
      };
      kernelOverride = kernel.override;
      wave6Dtb = delta.deviceTree.selectedDtb;
    };

    extraMeta = {
      description = "Release-pinned NXP i.MX95 kernel with Wave6 VPU support";
      homepage = source.repository;
      license = source.license;
      platforms = ["aarch64-linux"];
    };
  };
in
  kernel
