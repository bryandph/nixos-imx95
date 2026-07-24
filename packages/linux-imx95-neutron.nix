{
  buildLinux,
  fetchFromGitHub,
  lib,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  source = release.neutron.kernel.nxpReference;
  kernelSource = fetchFromGitHub source.fetchFromGitHub;
in
  buildLinux {
    pname = "linux-imx95-neutron";
    version = "6.18.20";
    modDirVersion = "6.18.20";

    src = kernelSource;
    features = {};
    defconfig = "imx_v8_defconfig";
    enableCommonConfig = false;
    autoModules = false;
    structuredExtraConfig = with lib.kernel; {
      ARCH_MXC = yes;
      REMOTEPROC = yes;
      IMX_NEUTRON_REMOTEPROC = yes;
      NEUTRON = yes;
    };
    ignoreConfigErrors = false;

    extraPassthru = {
      providerKind = "nxp-reference";
      releaseMapping = release;
      provenance = {
        repository = source.repository;
        branch = source.branch;
        rev = source.rev;
        delta = release.neutron.kernel.delta;
      };
      neutronDtb = "freescale/imx95-15x15-frdm-neutron.dtb";
      neutronUapi = "${kernelSource}/drivers/staging/neutron/uapi/neutron.h";
    };

    extraMeta = {
      description = "Release-pinned NXP i.MX95 kernel with Neutron NPU support";
      homepage = source.repository;
      license = source.license;
      platforms = ["aarch64-linux"];
    };
  }
