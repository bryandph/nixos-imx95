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
    unfreeLicense =
      lib.licenses.unfree
      // {
        fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
        redistributable = false;
      };
    offsetBytes = cfg.bootContainerOffsetKiB * 1024;
    environmentOffsetBytes = cfg.ubootEnvironmentOffsetKiB * 1024;
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
        default = 2976768;
        readOnly = true;
        description = "Expected size of the pinned LF6.18.20 FRDM boot container.";
      };

      ubootEnvironmentOffsetKiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7 * 1024;
        readOnly = true;
        description = "NXP U-Boot raw MMC environment offset.";
      };

      ubootEnvironmentSizeBytes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 16 * 1024;
        readOnly = true;
        description = "NXP U-Boot raw MMC environment size.";
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
        {
          assertion =
            environmentOffsetBytes
            + cfg.ubootEnvironmentSizeBytes
            <= reservedBytes;
          message = ''
            The FRDM-i.MX95 U-Boot environment would overlap the first
            filesystem partition.
          '';
        }
        {
          assertion =
            offsetBytes + cfg.bootContainerSizeBytes <= environmentOffsetBytes;
          message = ''
            The FRDM-i.MX95 boot container would overlap the U-Boot
            environment.
          '';
        }
      ];

      # generic-extlinux-compatible installs generations under /boot. The
      # generic SD-image module's noauto /boot/firmware mount would leave those
      # updates on the root filesystem instead of the FAT boot partition.
      fileSystems."/boot/firmware".enable = lib.mkForce false;
      fileSystems."/boot" = {
        device = "/dev/disk/by-label/BOOT";
        fsType = "vfat";
        options = ["nofail"];
      };

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

          cat > uboot.env.txt <<'EOF'
          bootcmd=bootflow scan -lb
          bootdelay=2
          boot_prefixes=/
          kernel_addr_r=0x90400000
          fdt_addr_r=0x95000000
          ramdisk_addr_r=0x98000000
          EOF

          ${lib.getExe' pkgs.ubootTools "mkenvimage"} \
            -s ${toString cfg.ubootEnvironmentSizeBytes} \
            -o uboot.env uboot.env.txt
          dd if=uboot.env of="$img" bs=1024 \
            seek=${toString cfg.ubootEnvironmentOffsetKiB} \
            conv=notrunc,fsync status=none

          # NXP U-Boot's bootflow rejects a DOS partition without the active
          # flag. The generic NixOS SD module places that flag on root instead.
          sfdisk --activate "$img" 1
        '';
      };

      systemd.services.expand-root-partition.script = lib.mkForce ''
        rootMajorMinor=$(${lib.getExe' pkgs.util-linux "findmnt"} -nr -o MAJ:MIN /)
        rootSysfs=$(${lib.getExe' pkgs.coreutils "readlink"} -f \
          "/sys/dev/block/$rootMajorMinor")
        rootName=''${rootSysfs##*/}
        parentSysfs=''${rootSysfs%/*}
        bootName=''${parentSysfs##*/}
        partNum=$(${lib.getExe' pkgs.coreutils "cat"} "$rootSysfs/partition")
        rootPart="/dev/$rootName"
        bootDevice="/dev/$bootName"

        echo "Expanding partition $partNum on $bootDevice for root $rootPart"

        echo ",+," | ${lib.getExe' pkgs.util-linux "sfdisk"} \
          -N "$partNum" --no-reread "$bootDevice"
        ${lib.getExe' pkgs.parted "partprobe"}
        ${lib.getExe' pkgs.e2fsprogs "resize2fs"} "$rootPart"
      '';

      system.build.frdmImx95SdImage = config.system.build.sdImage.overrideAttrs (old: {
        allowSubstitutes = false;
        preferLocalBuild = true;
        meta =
          (old.meta or {})
          // {
            description = "NixOS SD image for FRDM-i.MX95 containing licensed NXP firmware";
            license = unfreeLicense;
            hydraPlatforms = [];
            platforms = ["aarch64-linux"];
            sourceProvenance = with lib.sourceTypes; [
              fromSource
              binaryFirmware
              binaryNativeCode
            ];
          };
      });
    };
  };
}
