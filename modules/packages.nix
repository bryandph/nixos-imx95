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
          "imx-boot-imx95"
          "nxp-imx95-boot-container"
          "nixos-frdm-imx95.img.zst"
        ];
    });
  };
}
