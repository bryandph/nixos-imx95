{
  fetchFromGitHub,
  lib,
  pkgsCross,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  component = release.sources.optee;
  crossPkgs = pkgsCross.aarch64-multiplatform;
in
  crossPkgs.buildOptee {
    inherit (component) version;

    pname = component.pname;
    src = fetchFromGitHub component.fetchFromGitHub;
    platform = "imx";
    extraMakeFlags = [
      "PLATFORM_FLAVOR=${release.machine.opteePlatformFlavor}"
      "CFG_TEE_TA_LOG_LEVEL=0"
      "CFG_TEE_CORE_LOG_LEVEL=0"
    ];

    passthru = {
      inherit release;
      artifacts.teeRaw = component.build.artifact;
      provenance = {
        inherit (component) branch licenseFile;
        inherit (component.fetchFromGitHub) owner repo rev sha256;
      };
    };

    extraMeta = {
      description = "NXP OP-TEE OS for i.MX95";
      homepage = "https://github.com/nxp-imx/imx-optee-os";
      license = component.license;
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.fromSource];
    };
  }
