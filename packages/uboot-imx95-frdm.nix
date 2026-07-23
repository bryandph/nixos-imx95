{
  efitools,
  fetchFromGitHub,
  lib,
  pkgsCross,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  component = release.sources.uboot;
  crossPkgs = pkgsCross.aarch64-multiplatform;
in
  crossPkgs.buildUBoot {
    inherit (component) version;
    inherit (release.machine) ubootDefconfig;

    pname = component.pname;
    defconfig = release.machine.ubootDefconfig;
    src = fetchFromGitHub component.fetchFromGitHub;
    filesToInstall = [
      "spl/u-boot-spl.bin"
      "u-boot.bin"
      "u-boot-nodtb.bin"
      "u-boot.dtb"
    ];
    preBuild = ''
      export PATH=${lib.makeBinPath [efitools]}:$PATH
    '';

    passthru = {
      inherit release;
      artifacts = {
        spl = "u-boot-spl.bin";
        uboot = "u-boot.bin";
        ubootNodtb = "u-boot-nodtb.bin";
        dtb = "u-boot.dtb";
      };
      provenance = {
        inherit (component) branch licenseFile;
        inherit (component.fetchFromGitHub) owner repo rev sha256;
      };
    };

    extraMeta = {
      description = "NXP U-Boot for the FRDM-i.MX95";
      homepage = "https://github.com/nxp-imx/uboot-imx";
      license = component.license;
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.fromSource];
    };
  }
