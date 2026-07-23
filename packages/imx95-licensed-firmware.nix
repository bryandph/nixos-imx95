{
  callPackage,
  lib,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  downloadBase = "https://www.nxp.com/lgfiles/NMG/MAD/YOCTO";
  eleDistribution = release.licensedFirmware.ele.distribution;
  ddrDistribution = release.licensedFirmware.ddr.distribution;
  eleMember = builtins.head release.licensedFirmware.ele.members;
  ddrMembers = builtins.listToAttrs (
    map (member: {
      name = member.fileName;
      value = member;
    })
    release.licensedFirmware.ddr.members
  );
  mkFirmware = {
    distribution,
    member,
    pname,
  }:
    callPackage ./nxp-imx95-firmware-file.nix {
      inherit pname;
      inherit (member) fileName sha256 size;
      inherit distribution;
      version = release.release.version;
      downloadUrl = "${downloadBase}/${distribution.fileName}";
    };
in {
  ele = mkFirmware {
    pname = "nxp-imx95-ele-firmware";
    distribution = eleDistribution;
    member = eleMember;
  };
  lpddr4xDmem = mkFirmware {
    pname = "nxp-imx95-lpddr4x-dmem";
    distribution = ddrDistribution;
    member = ddrMembers."lpddr4x_dmem_v202409.bin";
  };
  lpddr4xDmemQuickBoot = mkFirmware {
    pname = "nxp-imx95-lpddr4x-dmem-qb";
    distribution = ddrDistribution;
    member = ddrMembers."lpddr4x_dmem_qb_v202409.bin";
  };
  lpddr4xImem = mkFirmware {
    pname = "nxp-imx95-lpddr4x-imem";
    distribution = ddrDistribution;
    member = ddrMembers."lpddr4x_imem_v202409.bin";
  };
  lpddr4xImemQuickBoot = mkFirmware {
    pname = "nxp-imx95-lpddr4x-imem-qb";
    distribution = ddrDistribution;
    member = ddrMembers."lpddr4x_imem_qb_v202409.bin";
  };
}
