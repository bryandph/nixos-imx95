{config, ...}: {
  flake.nixosModules = {
    frdm-imx95-core = config.flake.modules.nixos.frdm-imx95-core;
    frdm-imx95-sd-image = config.flake.modules.nixos.frdm-imx95-sd-image;
  };
}
