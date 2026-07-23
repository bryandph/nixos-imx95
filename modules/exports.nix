{config, ...}: {
  flake.nixosModules.boards.frdm-imx95 = {
    core = config.flake.modules.nixos.frdm-imx95-core;
    sd-image = config.flake.modules.nixos.frdm-imx95-sd-image;
  };
}
