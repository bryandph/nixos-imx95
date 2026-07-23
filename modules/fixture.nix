{
  config,
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.frdm-imx95 = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      config.flake.modules.nixos.frdm-imx95-core
      config.flake.modules.nixos.frdm-imx95-sd-image
      {
        nixpkgs.config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "imx-boot-imx95"
            "nxp-imx95-boot-container"
            "nixos-frdm-imx95.img.zst"
          ];

        networking = {
          hostName = "frdm-imx95";
          useDHCP = lib.mkDefault true;
        };

        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "prohibit-password";
        };

        image.baseName = "nixos-frdm-imx95";
        system.stateVersion = "26.05";
      }
    ];
  };

  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") (
      let
        board = config.flake.nixosConfigurations.frdm-imx95;
        bootContainer = board.config.hardware.nxp.imx95.bootContainer;
        bootContainerName = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all";
        sdImage = board.config.system.build.frdmImx95SdImage;
        bootContainerOffsetBytes = board.config.hardware.nxp.imx95.bootContainerOffsetKiB * 1024;
        firmwareOffsetBytes = board.config.sdImage.firmwarePartitionOffset * 1024 * 1024;
        rootOffsetBytes =
          (board.config.sdImage.firmwarePartitionOffset + board.config.sdImage.firmwareSize)
          * 1024
          * 1024;
      in {
        packages = {
          inherit sdImage;
          frdm-imx95-sd-image = sdImage;
          nxp-imx95-boot-container = bootContainer;
          default = sdImage;
        };

        checks = {
          module-evaluation = pkgs.runCommand "frdm-imx95-module-evaluation" {} ''
            test ${lib.escapeShellArg board.config.hardware.deviceTree.name} = \
              freescale/imx95-15x15-frdm.dtb
            test ${lib.escapeShellArg board.config.fileSystems."/".device} = \
              /dev/disk/by-label/NIXOS_SD
            test ${lib.escapeShellArg board.config.fileSystems."/boot/firmware".device} = \
              /dev/disk/by-label/BOOT
            test ${
              if sdImage.allowSubstitutes
              then "1"
              else "0"
            } = 0
            test ${
              if sdImage.meta.license.redistributable
              then "1"
              else "0"
            } = 0
            touch "$out"
          '';

          required-dtb = pkgs.runCommand "frdm-imx95-required-dtb" {} ''
            test -f \
              ${board.config.hardware.deviceTree.package}/freescale/imx95-15x15-frdm.dtb
            touch "$out"
          '';

          boot-artifacts = pkgs.runCommand "frdm-imx95-boot-artifacts" {} ''
              mkdir -p "$out"
              mkdir work
              cd work
              ln -s "$out" firmware
              ${board.config.sdImage.populateFirmwareCommands}

              test -f "$out/extlinux/extlinux.conf"
            grep -q '^  LINUX ../nixos/' "$out/extlinux/extlinux.conf"
            grep -q '^  INITRD ../nixos/' "$out/extlinux/extlinux.conf"
            grep -q '^  FDT ../nixos/' "$out/extlinux/extlinux.conf"
                  test -n "$(find "$out/nixos" -path '*/freescale/imx95-15x15-frdm.dtb' -print -quit)"
          '';

          sd-image-layout =
            pkgs.runCommand "frdm-imx95-sd-image-layout" {
              nativeBuildInputs = [
                pkgs.coreutils
                pkgs.e2fsprogs
                pkgs.mtools
                pkgs.util-linux
                pkgs.zstd
              ];
            } ''
              image=$(echo ${sdImage}/sd-image/*.img.zst)
              zstd --decompress --stdout "$image" > image.img

              firstStart=$(sfdisk --json image.img |
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].start')
              secondStart=$(sfdisk --json image.img |
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[1].start')

              test "$firstStart" -eq $(( ${toString firmwareOffsetBytes} / 512 ))
              test "$secondStart" -eq $(( ${toString rootOffsetBytes} / 512 ))

              dd if=image.img bs=1 skip=${toString bootContainerOffsetBytes} \
                count=${toString board.config.hardware.nxp.imx95.bootContainerSizeBytes} \
                status=none |
                cmp - "${bootContainer}/${bootContainerName}"

              mtype -i image.img@@${toString firmwareOffsetBytes} \
                ::/extlinux/extlinux.conf > extlinux.conf
              grep -q '^  LINUX ../nixos/' extlinux.conf
              grep -q '^  INITRD ../nixos/' extlinux.conf
              grep -q '^  FDT ../nixos/' extlinux.conf

              rootLabel=$(blkid -p -O ${toString rootOffsetBytes} \
                -s LABEL -o value image.img)
              test "$rootLabel" = NIXOS_SD

              mkdir "$out"
              cp extlinux.conf "$out/"
              sfdisk --json image.img > "$out/partition-table.json"
              sha256sum image.img > "$out/image.sha256"
            '';
        };
      }
    );
}
