{...}: {
  flake.modules.nixos.frdm-imx95-sd-image = {
    config,
    lib,
    modulesPath,
    pkgs,
    ...
  }: let
    cfg = config.hardware.nxp.imx95;
    bootContainerName = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all";
    bootContainerPath =
      if cfg.bootContainer == null
      then "/dev/null"
      else "${cfg.bootContainer}/${bootContainerName}";
    offsetBytes = cfg.bootContainerOffsetKiB * 1024;
    reservedBytes = cfg.reservedBootRegionMiB * 1024 * 1024;
  in {
    imports = [
      "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ];

    options.hardware.nxp.imx95 = {
      bootContainer = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.callPackage ../../../packages/nxp-imx95-boot-container.nix {};
        defaultText = lib.literalExpression "pkgs.callPackage <nixos-imx95 boot-container package> {}";
        description = ''
          Hash-verified, operator-supplied NXP AHAB boot-container package.
          This artifact is unfree and must not be redistributed standalone.
        '';
      };

      bootContainerOffsetKiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 32;
        readOnly = true;
        description = "Vendor-defined raw SD offset for the i.MX95 boot container.";
      };

      bootContainerSizeBytes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2829312;
        readOnly = true;
        description = "Expected size of the pinned LF6.18.2 FRDM boot container.";
      };

      reservedBootRegionMiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8;
        readOnly = true;
        description = "Raw region reserved before the first filesystem partition.";
      };
    };

    config = {
      assertions = [
        {
          assertion = cfg.bootContainer != null;
          message = ''
            FRDM-i.MX95 SD-image construction requires a configured NXP boot
            container. Import the licensed artifact with
            scripts/import-nxp-boot-container.
          '';
        }
        {
          assertion = offsetBytes + cfg.bootContainerSizeBytes <= reservedBytes;
          message = ''
            The FRDM-i.MX95 boot container would overlap the first filesystem
            partition. Refusing to produce an unsafe SD image.
          '';
        }
      ];

      sdImage = {
        compressImage = true;
        firmwarePartitionOffset = cfg.reservedBootRegionMiB;
        firmwarePartitionID = "0x95465244";
        firmwarePartitionName = "BOOT";
        firmwareSize = 512;
        rootPartitionUUID = "d4b95ed2-4fbd-45d8-bd74-8ba0f5353e31";
        rootVolumeLabel = "NIXOS_SD";

        populateFirmwareCommands = lib.mkForce ''
          mkdir -p ./firmware
          ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
            -c ${config.system.build.toplevel} -d ./firmware
        '';

        populateRootCommands = lib.mkForce ''
          mkdir -p ./files/boot
        '';

        postBuildCommands = ''
          bootContainer=${lib.escapeShellArg bootContainerPath}
          actualSize=$(stat -c %s "$bootContainer")

          if [ "$actualSize" -ne ${toString cfg.bootContainerSizeBytes} ]; then
            echo "NXP boot container has size $actualSize; expected ${toString cfg.bootContainerSizeBytes}" >&2
            exit 1
          fi

          if [ $(( ${toString offsetBytes} + actualSize )) -gt ${toString reservedBytes} ]; then
            echo "NXP boot container overlaps the first partition" >&2
            exit 1
          fi

          dd if="$bootContainer" of="$img" bs=1024 \
            seek=${toString cfg.bootContainerOffsetKiB} conv=notrunc,fsync status=none
        '';
      };
    };
  };
}
