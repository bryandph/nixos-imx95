{
  inputs,
  lib,
  ...
}: {
  perSystem = {system, ...}: {
    _module.args.pkgs = lib.mkForce (import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "frdm-imx95-source-boot-container"
          "frdm-imx95-source-container-reproducibility"
          "frdm-imx95-source-container-structure"
          "frdm-imx95-source-sd-image-layout"
          "imx-boot-imx95"
          "lpddr4x_dmem_qb_v202409.bin"
          "lpddr4x_dmem_v202409.bin"
          "lpddr4x_imem_qb_v202409.bin"
          "lpddr4x_imem_v202409.bin"
          "mx95b0-ahab-container.img"
          "nxp-imx95-boot-container"
          "nxp-imx95-ele-firmware"
          "nxp-imx95-lpddr4x-dmem"
          "nxp-imx95-lpddr4x-dmem-qb"
          "nxp-imx95-lpddr4x-imem"
          "nxp-imx95-lpddr4x-imem-qb"
          "nixos-frdm-imx95.img.zst"
          "nixos-frdm-imx95-source-built.img.zst"
        ];
    });
  };
}
