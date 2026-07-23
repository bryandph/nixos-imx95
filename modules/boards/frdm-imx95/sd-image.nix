{...}: {
  flake.modules.nixos.frdm-imx95-sd-image = {
    config,
    lib,
    modulesPath,
    pkgs,
    ...
  }: let
    cfg = config.hardware.nxp.imx95;
    defaultBootContainer = pkgs.callPackage ../../../packages/nxp-imx95-boot-container.nix {};
    provider =
      if cfg.bootContainer == null
      then {}
      else cfg.bootContainer;
    requiredProviderMetadata = [
      "bootContainerOffsetKiB"
      "componentManifest"
      "containsM7Application"
      "expectedHash"
      "expectedSha256"
      "expectedSize"
      "fileName"
      "providerKind"
      "providerLicense"
      "release"
      "reservedBootRegionMiB"
      "ubootEnvironmentOffsetKiB"
      "ubootEnvironmentSizeBytes"
    ];
    hasProviderMetadata =
      lib.all (name: builtins.hasAttr name provider) requiredProviderMetadata;
    bootContainerName = provider.fileName or "missing-provider-file-name";
    bootContainerPath =
      if cfg.bootContainer == null
      then "/dev/null"
      else "${cfg.bootContainer}/${bootContainerName}";
    unfreeLicense =
      provider.providerLicense or (
        lib.licenses.unfree
        // {
          fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
          redistributable = false;
        }
      );
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
        default = defaultBootContainer;
        defaultText = lib.literalExpression "pkgs.callPackage <nixos-imx95 boot-container provider> {}";
        description = ''
          Boot-container provider implementing the nixos-imx95 metadata
          contract. Providers may assemble from source plus granular licensed
          firmware or wrap a hash-verified complete NXP container.
        '';
      };

      bootContainerOffsetKiB = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared raw SD offset for the i.MX95 boot container.";
      };

      bootContainerSizeBytes = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared size of the selected boot container.";
      };

      ubootEnvironmentOffsetKiB = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared NXP U-Boot raw MMC environment offset.";
      };

      ubootEnvironmentSizeBytes = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared NXP U-Boot raw MMC environment size.";
      };

      reservedBootRegionMiB = lib.mkOption {
        type = lib.types.ints.positive;
        readOnly = true;
        description = "Provider-declared raw region before the first filesystem partition.";
      };
    };

    config = {
      hardware.nxp.imx95 = {
        bootContainerOffsetKiB = provider.bootContainerOffsetKiB or 1;
        bootContainerSizeBytes = provider.expectedSize or 1;
        reservedBootRegionMiB = provider.reservedBootRegionMiB or 1;
        ubootEnvironmentOffsetKiB = provider.ubootEnvironmentOffsetKiB or 1;
        ubootEnvironmentSizeBytes = provider.ubootEnvironmentSizeBytes or 1;
      };

      assertions = [
        {
          assertion = hasProviderMetadata;
          message = ''
            The selected FRDM-i.MX95 boot-container package does not implement
            the required provider metadata contract.
          '';
        }
        {
          assertion = (provider.providerLicense.redistributable or true) == false;
          message = ''
            The selected FRDM-i.MX95 boot-container provider must retain the
            non-redistributable NXP license boundary.
          '';
        }
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
          ${lib.getExe pkgs.bash} \
            ${../../../scripts/check-imx95-boot-container} \
            "$bootContainer" \
            ${lib.escapeShellArg (provider.expectedSha256 or "missing")} \
            ${toString cfg.bootContainerSizeBytes} \
            ${toString offsetBytes} \
            ${toString reservedBytes} \
            ${toString environmentOffsetBytes}

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
