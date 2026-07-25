{config, ...}: {
  flake.nixosModules = {
    frdm-imx95-core = config.flake.modules.nixos.frdm-imx95-core;
    frdm-imx95-m7-remoteproc = config.flake.modules.nixos.frdm-imx95-m7-remoteproc;
    frdm-imx95-multimedia = config.flake.modules.nixos.frdm-imx95-multimedia;
    frdm-imx95-neutron-npu = config.flake.modules.nixos.frdm-imx95-neutron-npu;
    frdm-imx95-sd-image = config.flake.modules.nixos.frdm-imx95-sd-image;
    frdm-imx95-wave6-vpu = config.flake.modules.nixos.frdm-imx95-wave6-vpu;
  };
}
