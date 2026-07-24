{...}: {
  perSystem = {pkgs, ...}: {
    packages.frdm-imx95-m7-ctl =
      pkgs.callPackage ../packages/frdm-imx95-m7-ctl.nix {};
  };
}
