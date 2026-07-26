{inputs, ...}: {
  flake.modules.nixos.frdm-imx95-nvme = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    nvmeSmoke = inputs.self.packages.${system}.frdm-imx95-nvme-smoke;
    kernel = config.boot.kernelPackages.kernel;
    providerKind = kernel.providerKind or "upstream";
  in {
    environment.systemPackages = [
      nvmeSmoke
      pkgs.nvme-cli
      pkgs.pciutils
    ];
    system.build.nvmeSmoke = nvmeSmoke;

    assertions = [
      {
        assertion =
          providerKind
          != "nxp-full-combined"
          || builtins.elem "nvme" kernel.capabilities;
        message = "The combined NXP kernel must advertise the FRDM NVMe capability.";
      }
    ];
  };
}
