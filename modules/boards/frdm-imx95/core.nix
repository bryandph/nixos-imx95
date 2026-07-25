{...}: {
  flake.modules.nixos.frdm-imx95-core = {
    config,
    lib,
    pkgs,
    ...
  }: let
    requiredDtb = "freescale/imx95-15x15-frdm.dtb";
    providerKind = config.boot.kernelPackages.kernel.providerKind or "upstream";
  in {
    boot = {
      kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      consoleLogLevel = lib.mkDefault 7;
      supportedFilesystems = lib.mkForce [
        "ext4"
        "vfat"
      ];

      initrd.availableKernelModules = [
        "mmc_block"
        "sdhci"
        "sdhci-esdhc-imx"
      ];

      kernelParams = lib.mkForce [
        "rootwait"
        "earlycon"
        "keep_bootcon"
        "console=ttyLP0,115200"
        "loglevel=7"
      ];

      loader = {
        grub.enable = lib.mkForce false;
        generic-extlinux-compatible = {
          enable = lib.mkForce true;
          configurationLimit = lib.mkForce 0;
        };
      };
    };

    hardware.deviceTree = {
      enable = true;
      filter = "imx95-15x15-frdm.dtb";
      name = requiredDtb;
    };

    assertions = [
      {
        assertion =
          lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.0"
          || builtins.elem providerKind [
            "full-nxp-reference"
            "nxp-full-combined"
          ];
        message = ''
          FRDM-i.MX95 requires Linux 7.0 or newer for the upstream
          ${requiredDtb} board device tree, except when an optional feature
          explicitly selects a reviewed release-pinned full NXP provider.
        '';
      }
      {
        assertion = config.hardware.deviceTree.name == requiredDtb;
        message = "FRDM-i.MX95 must boot with the accepted ${requiredDtb} name.";
      }
    ];
  };
}
