{
  fetchFromGitHub,
  lib,
  pkgsCross,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  component = release.sources.armTrustedFirmware;
  crossPkgs = pkgsCross.aarch64-multiplatform;
in
  crossPkgs.buildArmTrustedFirmware {
    inherit (component) version;

    pname = component.pname;
    src = fetchFromGitHub component.fetchFromGitHub;
    platform = release.machine.atfPlatform;
    filesToInstall = ["build/${release.machine.atfPlatform}/release/bl31.bin"];
    extraMakeFlags = ["SPD=opteed"];

    # Nixpkgs' generic builder carries a Rockchip-only blob-removal patch.
    # This NXP source is blob-free for i.MX95 and does not need that patch.
    patches = [];
    postPatch = "";

    passthru = {
      inherit release;
      artifacts.bl31 = "bl31.bin";
      provenance = {
        inherit (component) branch licenseFile;
        inherit (component.fetchFromGitHub) owner repo rev sha256;
      };
    };

    extraMeta = {
      description = "NXP Trusted Firmware-A BL31 for i.MX95";
      homepage = "https://github.com/nxp-imx/imx-atf";
      license = component.license;
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.fromSource];
    };
  }
