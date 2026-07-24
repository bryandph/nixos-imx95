{
  config,
  inputs,
  lib,
  ...
}: let
  release = import ../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  m7Vring0 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 0;
  m7Vring1 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 1;
  m7Vring2 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 2;
  m7Vring3 = builtins.elemAt release.m7.remoteproc.sharedMemory.vrings 3;
  allowedUnfreeNames = [
    "frdm-imx95-source-boot-container"
    "frdm-imx95-source-container-reproducibility"
    "frdm-imx95-source-container-structure"
    "frdm-imx95-source-sd-image-layout"
    "imx-boot-imx95"
    "lpddr4x_dmem_qb_v202409.bin"
    "lpddr4x_dmem_v202409.bin"
    "lpddr4x_imem_qb_v202409.bin"
    "lpddr4x_imem_v202409.bin"
    "mx95b0-ahab-container.img"
    "nxp-imx95-boot-container"
    "nxp-imx95-ele-firmware"
    "nxp-imx95-lpddr4x-dmem"
    "nxp-imx95-lpddr4x-dmem-qb"
    "nxp-imx95-lpddr4x-imem"
    "nxp-imx95-lpddr4x-imem-qb"
    "nixos-frdm-imx95-compatibility.img.zst"
    "nixos-frdm-imx95-m7-remoteproc.img.zst"
    "nixos-frdm-imx95.img.zst"
    "nixos-frdm-imx95-source-built.img.zst"
  ];

  boardModule = imageBaseName: {
    networking = {
      hostName = "frdm-imx95";
      useDHCP = lib.mkDefault true;
    };

    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) allowedUnfreeNames;

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "prohibit-password";
    };

    image.baseName = imageBaseName;
    system.stateVersion = "26.05";
  };

  mkBoard = {
    imageBaseName,
    modules ? [],
  }:
    inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules =
        [
          config.flake.modules.nixos.frdm-imx95-core
          config.flake.modules.nixos.frdm-imx95-sd-image
          (boardModule imageBaseName)
        ]
        ++ modules;
    };
in {
  flake.nixosConfigurations = {
    frdm-imx95 = mkBoard {
      imageBaseName = "nixos-frdm-imx95";
    };

    frdm-imx95-source-built = mkBoard {
      imageBaseName = "nixos-frdm-imx95-source-built";
    };

    frdm-imx95-m7-remoteproc = mkBoard {
      imageBaseName = "nixos-frdm-imx95-m7-remoteproc";
      modules = [
        config.flake.modules.nixos.frdm-imx95-m7-remoteproc
      ];
    };

    frdm-imx95-compatibility = mkBoard {
      imageBaseName = "nixos-frdm-imx95-compatibility";
      modules = [
        ({pkgs, ...}: {
          hardware.nxp.imx95.bootContainer =
            pkgs.callPackage ../packages/nxp-imx95-boot-container.nix {};
        })
      ];
    };
  };

  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") (
      let
        board = config.flake.nixosConfigurations.frdm-imx95;
        m7Board = config.flake.nixosConfigurations.frdm-imx95-m7-remoteproc;
        sourceBoard = board;
        compatibilityBoard = config.flake.nixosConfigurations.frdm-imx95-compatibility;
        compatibilityBootContainer = compatibilityBoard.config.hardware.nxp.imx95.bootContainer;
        compatibilityBootContainerName = compatibilityBootContainer.fileName;
        sdImage = board.config.system.build.frdmImx95SdImage;
        sourceSdImage = sourceBoard.config.system.build.frdmImx95SdImage;
        compatibilitySdImage = compatibilityBoard.config.system.build.frdmImx95SdImage;
        configuredSourceBootContainer = sourceBoard.config.hardware.nxp.imx95.bootContainer;
        sourceManifestNames =
          map
          (component: component.name)
          configuredSourceBootContainer.componentManifest;
        expectedSourceManifestNames = [
          "imx-atf-imx95"
          "imx-mkimage-imx95"
          "imx-oei-imx95-frdm"
          "imx-optee-os-imx95"
          "imx-system-manager-imx95"
          "lpddr4x_dmem_qb_v202409.bin"
          "lpddr4x_dmem_v202409.bin"
          "lpddr4x_imem_qb_v202409.bin"
          "lpddr4x_imem_v202409.bin"
          "mx95b0-ahab-container.img"
          "uboot-imx95-frdm"
        ];
        sourceProvenanceNames =
          map
          (provenance: provenance.shortName)
          configuredSourceBootContainer.meta.sourceProvenance;
        uboot = pkgs.callPackage ../packages/uboot-imx95-frdm.nix {};
        armTrustedFirmware = pkgs.callPackage ../packages/imx-atf-imx95.nix {};
        optee = pkgs.callPackage ../packages/imx-optee-os-imx95.nix {};
        systemManager = pkgs.callPackage ../packages/imx-system-manager-imx95.nix {};
        oei = pkgs.callPackage ../packages/imx-oei-imx95-frdm.nix {};
        imxMkimage = pkgs.callPackage ../packages/imx-mkimage-imx95.nix {};
        licensedFirmware = pkgs.callPackage ../packages/imx95-licensed-firmware.nix {};
        rustToolchain = let
          fenix = inputs.fenix.packages.${system};
          native = fenix.toolchainOf {
            channel = "1.85.1";
            sha256 = "sha256-Hn2uaQzRLidAWpfmRwSRdImifGUCAb9HeAqTYFXWeQk=";
          };
          target = fenix.targets.thumbv7em-none-eabihf.toolchainOf {
            channel = "1.85.1";
            sha256 = "sha256-Hn2uaQzRLidAWpfmRwSRdImifGUCAb9HeAqTYFXWeQk=";
          };
        in
          fenix.combine [
            native.cargo
            native.rustc
            target.rust-std
          ];
        firmwareRustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
        m7SmokeFirmware = pkgs.callPackage ../packages/frdm-imx95-m7-smoke.nix {
          rustPlatform = firmwareRustPlatform;
        };
        sourceBootContainer = pkgs.callPackage ../packages/imx95-source-boot-container.nix {};
        sourceBootContainerReproA = pkgs.callPackage ../packages/imx95-source-boot-container.nix {
          buildInstance = "repro-a";
        };
        sourceBootContainerReproB = pkgs.callPackage ../packages/imx95-source-boot-container.nix {
          buildInstance = "repro-b";
        };
        missingMetadataProvider = pkgs.runCommand "frdm-imx95-missing-metadata-provider" {} ''
          mkdir "$out"
        '';
        missingMetadataBoard = mkBoard {
          imageBaseName = "nixos-frdm-imx95-invalid-metadata";
          modules = [
            {hardware.nxp.imx95.bootContainer = missingMetadataProvider;}
          ];
        };
        unsafeProvider =
          sourceBootContainer
          // {
            expectedSize = 8 * 1024 * 1024;
          };
        unsafeProviderBoard = mkBoard {
          imageBaseName = "nixos-frdm-imx95-unsafe-provider";
          modules = [
            {hardware.nxp.imx95.bootContainer = unsafeProvider;}
          ];
        };
        failedAssertions = boardConfig:
          builtins.filter (assertion: !assertion.assertion) boardConfig.config.assertions;
        compatibilityBootContainerOffsetBytes =
          compatibilityBoard.config.hardware.nxp.imx95.bootContainerOffsetKiB * 1024;
        sourceBootContainerOffsetBytes =
          sourceBoard.config.hardware.nxp.imx95.bootContainerOffsetKiB * 1024;
        ubootEnvironmentOffsetBytes =
          board.config.hardware.nxp.imx95.ubootEnvironmentOffsetKiB * 1024;
        compatibilityUbootEnvironmentOffsetBytes =
          compatibilityBoard.config.hardware.nxp.imx95.ubootEnvironmentOffsetKiB * 1024;
        firmwareOffsetBytes = board.config.sdImage.firmwarePartitionOffset * 1024 * 1024;
        rootOffsetBytes =
          (board.config.sdImage.firmwarePartitionOffset + board.config.sdImage.firmwareSize)
          * 1024
          * 1024;
      in {
        packages = {
          inherit
            armTrustedFirmware
            imxMkimage
            m7SmokeFirmware
            oei
            optee
            sdImage
            systemManager
            uboot
            ;
          frdm-imx95-sd-image = sdImage;
          frdm-imx95-m7-remoteproc-sd-image =
            m7Board.config.system.build.frdmImx95SdImage;
          frdm-imx95-m7-smoke = m7SmokeFirmware;
          frdm-imx95-source-boot-container = sourceBootContainer;
          frdm-imx95-source-built-sd-image = sourceSdImage;
          frdm-imx95-compatibility-sd-image = compatibilitySdImage;
          imx-atf-imx95 = armTrustedFirmware;
          imx-mkimage-imx95 = imxMkimage;
          imx-oei-imx95-frdm = oei;
          imx-optee-os-imx95 = optee;
          imx-system-manager-imx95 = systemManager;
          nxp-imx95-boot-container = compatibilityBootContainer;
          nxp-imx95-ele-firmware = licensedFirmware.ele;
          nxp-imx95-lpddr4x-dmem = licensedFirmware.lpddr4xDmem;
          nxp-imx95-lpddr4x-dmem-qb = licensedFirmware.lpddr4xDmemQuickBoot;
          nxp-imx95-lpddr4x-imem = licensedFirmware.lpddr4xImem;
          nxp-imx95-lpddr4x-imem-qb = licensedFirmware.lpddr4xImemQuickBoot;
          uboot-imx95-frdm = uboot;
          default = sdImage;
        };

        checks = {
          m7-firmware-layout =
            pkgs.runCommand "frdm-imx95-m7-firmware-layout" {
              nativeBuildInputs = [
                pkgs.binutils
                pkgs.jq
              ];
            } ''
              elf=${m7SmokeFirmware}/${m7SmokeFirmware.firmwarePath}
              provenance=${m7SmokeFirmware}/share/frdm-imx95-m7-smoke/provenance.json
              headers=$(readelf --file-header "$elf")

              grep -q 'Class:.*ELF32' <<<"$headers"
              grep -q "Data:.*2's complement, little endian" <<<"$headers"
              grep -q 'Machine:.*ARM' <<<"$headers"
              grep -q 'Type:.*EXEC' <<<"$headers"
              grep -q 'Entry point address:.*0x401' <<<"$headers"
              grep -q 'hard-float ABI' <<<"$headers"

              assert_section_range() {
                local section="$1"
                local range_start="$2"
                local range_end="$3"
                local fields
                local address
                local size
                local section_end

                range_start=$((range_start))
                range_end=$((range_end))
                fields=$(
                  readelf --wide --sections "$elf" |
                    awk -v section="$section" '$3 == section { print $5, $7 }'
                )
                test -n "$fields"
                set -- $fields
                address=$((0x$1))
                size=$((0x$2))
                section_end=$((address + size))
                test "$address" -ge "$range_start"
                test "$section_end" -le "$range_end"
              }

              assert_section_range .vector_table 0x00000000 0x00040000
              assert_section_range .text 0x00000000 0x00040000
              assert_section_range .rodata 0x00000000 0x00040000
              assert_section_range .resource_table 0x00000000 0x00040000
              assert_section_range .data 0x20000000 0x20040000
              assert_section_range .bss 0x20000000 0x20040000
              assert_section_range .uninit 0x20000000 0x20040000

              resource_size=$(
                readelf --wide --sections "$elf" |
                  awk '$3 == ".resource_table" { print $7 }'
              )
              test "$resource_size" = 000010

              jq -e '
                .firmware.license == "MIT" and
                .bsp.license == "MIT OR Apache-2.0" and
                .bsp.rev == "8b92ab5b228aaee86fa5ee0df6534d944e3c8e67" and
                .bsp.archiveHash ==
                  "sha256-McLRisrw6Z0NHQxNCkKIy7c7ZXw2n2iW6GkxplIfwO4=" and
                .rust.target == "thumbv7em-none-eabihf" and
                .rust.toolchain == "1.85.1"
              ' "$provenance" >/dev/null

              test ${
                if m7SmokeFirmware.licensedNxpArtifacts == []
                then "1"
                else "0"
              } = 1
              test "$(find ${m7SmokeFirmware} -type f | wc -l)" -eq 2
              test -z "$(
                find ${m7SmokeFirmware} -type f \
                  \( -name '*.bin' -o -name '*.img' -o -name '*.fw' \)
              )"

              touch "$out"
            '';

          module-evaluation = pkgs.runCommand "frdm-imx95-module-evaluation" {} ''
            test ${lib.escapeShellArg configuredSourceBootContainer.providerKind} = \
              source-assembled
            test ${lib.escapeShellArg configuredSourceBootContainer.release} = \
              6.18.20-2.0.0
            test ${lib.escapeShellArg configuredSourceBootContainer.fileName} = \
              imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55
            test ${toString configuredSourceBootContainer.expectedSize} -eq \
              ${toString board.config.hardware.nxp.imx95.bootContainerSizeBytes}
            test ${toString configuredSourceBootContainer.bootContainerOffsetKiB} -eq \
              ${toString board.config.hardware.nxp.imx95.bootContainerOffsetKiB}
            test ${lib.escapeShellArg board.config.hardware.deviceTree.name} = \
              freescale/imx95-15x15-frdm.dtb
            test ${lib.escapeShellArg board.config.fileSystems."/".device} = \
              /dev/disk/by-label/NIXOS_SD
            test ${
              if builtins.hasAttr "/boot" board.config.fileSystems
              then "1"
              else "0"
            } = 0
            bootGenerator=${
              lib.escapeShellArg board.config.systemd.generators.frdm-imx95-root-boot
            }
            test -x "$bootGenerator"
            grep -q 'rootMajorMinor=' "$bootGenerator"
            grep -q 'bootPartition=' "$bootGenerator"
            test ${
              if builtins.hasAttr "/boot/firmware" board.config.fileSystems
              then "1"
              else "0"
            } = 0
            test ${
              if lib.hasInfix ''-N "$partNum"'' board.config.systemd.services.expand-root-partition.script
              then "1"
              else "0"
            } = 1
            test ${
              if lib.hasInfix "/sys/dev/block/" board.config.systemd.services.expand-root-partition.script
              then "1"
              else "0"
            } = 1
            test ${
              if lib.hasInfix "-nr -o MAJ:MIN" board.config.systemd.services.expand-root-partition.script
              then "1"
              else "0"
            } = 1
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

          compatibility-provider-evaluation = pkgs.runCommand "frdm-imx95-compatibility-provider-evaluation" {} ''
            test ${lib.escapeShellArg compatibilityBootContainer.providerKind} = \
              nxp-complete-container
            test ${lib.escapeShellArg compatibilityBootContainer.release} = \
              6.18.20-2.0.0
            test ${lib.escapeShellArg compatibilityBootContainer.fileName} = \
              imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all
            test ${toString compatibilityBootContainer.expectedSize} -eq \
              ${toString compatibilityBoard.config.hardware.nxp.imx95.bootContainerSizeBytes}
            test ${
              if compatibilitySdImage.allowSubstitutes
              then "1"
              else "0"
            } = 0
            test ${
              if compatibilitySdImage.meta.license.redistributable
              then "1"
              else "0"
            } = 0
            touch "$out"
          '';

          source-provider-evaluation = pkgs.runCommand "frdm-imx95-source-provider-evaluation" {} ''
            test ${lib.escapeShellArg configuredSourceBootContainer.providerKind} = \
              source-assembled
            test ${lib.escapeShellArg configuredSourceBootContainer.release} = \
              6.18.20-2.0.0
            test ${lib.escapeShellArg configuredSourceBootContainer.fileName} = \
              imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55
            test ${toString configuredSourceBootContainer.expectedSize} -eq \
              ${toString sourceBoard.config.hardware.nxp.imx95.bootContainerSizeBytes}
            test ${toString (builtins.length sourceManifestNames)} -eq \
              ${toString (builtins.length expectedSourceManifestNames)}
            test ${
              if
                lib.all
                (name: builtins.elem name sourceManifestNames)
                expectedSourceManifestNames
              then "1"
              else "0"
            } = 1
            test ${
              if builtins.elem "fromSource" sourceProvenanceNames
              then "1"
              else "0"
            } = 1
            test ${
              if builtins.elem "binaryFirmware" sourceProvenanceNames
              then "1"
              else "0"
            } = 1
            test ${
              if configuredSourceBootContainer.allowSubstitutes
              then "1"
              else "0"
            } = 0
            test ${
              if configuredSourceBootContainer.meta.license.redistributable
              then "1"
              else "0"
            } = 0
            test ${toString (builtins.length configuredSourceBootContainer.meta.hydraPlatforms)} -eq 0
            test ${
              if configuredSourceBootContainer.containsM7Application
              then "1"
              else "0"
            } = 0
            test ${
              if sourceSdImage.allowSubstitutes
              then "1"
              else "0"
            } = 0
            test ${
              if sourceSdImage.meta.license.redistributable
              then "1"
              else "0"
            } = 0
            touch "$out"
          '';

          firmware-fail-closed =
            pkgs.runCommand "frdm-imx95-firmware-fail-closed" {
              nativeBuildInputs = [pkgs.coreutils];
            } ''
              printf valid-firmware > firmware.bin
              validHash=$(sha256sum firmware.bin | cut -d' ' -f1)
              validSize=$(stat -c %s firmware.bin)

              ${lib.getExe pkgs.bash} ${../scripts/check-nxp-firmware-file} \
                firmware.bin "$validHash" "$validSize"

              if ${lib.getExe pkgs.bash} ${../scripts/check-nxp-firmware-file} \
                missing.bin "$validHash" "$validSize"; then
                echo "missing firmware unexpectedly passed validation" >&2
                exit 1
              fi
              if ${lib.getExe pkgs.bash} ${../scripts/check-nxp-firmware-file} \
                firmware.bin \
                0000000000000000000000000000000000000000000000000000000000000000 \
                "$validSize"; then
                echo "mismatched firmware identity unexpectedly passed validation" >&2
                exit 1
              fi
              if ${lib.getExe pkgs.bash} ${../scripts/check-nxp-firmware-file} \
                firmware.bin "$validHash" "$(( validSize + 1 ))"; then
                echo "mismatched firmware size unexpectedly passed validation" >&2
                exit 1
              fi

              touch "$out"
            '';

          provider-fail-closed =
            pkgs.runCommand "frdm-imx95-provider-fail-closed" {
              nativeBuildInputs = [pkgs.coreutils];
            } ''
              printf valid-container > container.bin
              validHash=$(sha256sum container.bin | cut -d' ' -f1)
              validSize=$(stat -c %s container.bin)

              validate=${../scripts/check-imx95-boot-container}
              ${lib.getExe pkgs.bash} "$validate" \
                container.bin "$validHash" "$validSize" 32768 8388608 7340032

              if ${lib.getExe pkgs.bash} "$validate" \
                missing.bin "$validHash" "$validSize" 32768 8388608 7340032; then
                echo "missing provider output unexpectedly passed validation" >&2
                exit 1
              fi
              if ${lib.getExe pkgs.bash} "$validate" \
                container.bin \
                0000000000000000000000000000000000000000000000000000000000000000 \
                "$validSize" 32768 8388608 7340032; then
                echo "provider identity mismatch unexpectedly passed validation" >&2
                exit 1
              fi
              if ${lib.getExe pkgs.bash} "$validate" \
                container.bin "$validHash" "$(( validSize + 1 ))" \
                32768 8388608 7340032; then
                echo "provider size mismatch unexpectedly passed validation" >&2
                exit 1
              fi
              if ${lib.getExe pkgs.bash} "$validate" \
                container.bin "$validHash" "$validSize" \
                7340032 8388608 7340032; then
                echo "unsafe provider unexpectedly passed validation" >&2
                exit 1
              fi

              test ${
                if
                  lib.any
                  (failure: lib.hasInfix "metadata contract" failure.message)
                  (failedAssertions missingMetadataBoard)
                then "1"
                else "0"
              } = 1
              test ${
                if
                  lib.any
                  (failure: lib.hasInfix "overlap" failure.message)
                  (failedAssertions unsafeProviderBoard)
                then "1"
                else "0"
              } = 1

              touch "$out"
            '';

          source-container-structure =
            pkgs.runCommand "frdm-imx95-source-container-structure" {
              allowSubstitutes = false;
              preferLocalBuild = true;
              meta = {
                license = configuredSourceBootContainer.providerLicense;
                hydraPlatforms = [];
              };
            } ''
              ${imxMkimage}/bin/mkimage_imx8 \
                -soc IMX9 \
                -parse \
                "${configuredSourceBootContainer}/${configuredSourceBootContainer.fileName}" \
                > inventory.txt
              ${imxMkimage}/bin/mkimage_imx8 \
                -soc IMX9 \
                -extract \
                "${configuredSourceBootContainer}/${configuredSourceBootContainer.fileName}" \
                > /dev/null

              install -m0644 "${optee}/${optee.artifacts.teeRaw}" expected-tee.bin
              truncate \
                -s "$(stat -c %s extracted_imgs/app_container1_img3.bin)" \
                expected-tee.bin
              cmp expected-tee.bin extracted_imgs/app_container1_img3.bin

              grep -q 'IMAGE 1 (ELE FW)' inventory.txt
              grep -q 'IMAGE 2 (DDR Init)' inventory.txt
              grep -q 'IMAGE 3 (M33)' inventory.txt
              grep -q 'CORE_CM33' inventory.txt
              grep -q 'IMAGE 4 (Bootloader)' inventory.txt
              grep -q 'CORE_CA55' inventory.txt
              grep -q 'Load Addr: 0X8A200000' inventory.txt
              grep -q 'Load Addr: 0X90200000' inventory.txt
              grep -q 'Load Addr: 0X8C000000' inventory.txt
              test "$(grep -c 'A core Image' inventory.txt)" -eq 3
              if grep -Eq 'M7|CORE_CM7' inventory.txt; then
                echo "unexpected M7 application payload in source-built container" >&2
                exit 1
              fi

              touch "$out"
            '';

          source-container-reproducibility =
            pkgs.runCommand "frdm-imx95-source-container-reproducibility" {
              allowSubstitutes = false;
              preferLocalBuild = true;
              meta = {
                license = configuredSourceBootContainer.providerLicense;
                hydraPlatforms = [];
              };
            } ''
              cmp \
                "${sourceBootContainerReproA}/${sourceBootContainerReproA.fileName}" \
                "${sourceBootContainerReproB}/${sourceBootContainerReproB.fileName}"
              touch "$out"
            '';

          m7-remoteproc-dtb =
            pkgs.runCommand "frdm-imx95-m7-remoteproc-dtb" {
              nativeBuildInputs = [
                pkgs.dtc
                pkgs.gnutar
                pkgs.xz
              ];
            } ''
              m7Dtb=${m7Board.config.hardware.deviceTree.package}/freescale/imx95-15x15-frdm.dtb
              baselineDtb=${board.config.hardware.deviceTree.package}/freescale/imx95-15x15-frdm.dtb
              kernelSrc=${m7Board.config.boot.kernelPackages.kernel.src}
              tar -xOf "$kernelSrc" --wildcards '*/drivers/remoteproc/imx_rproc.c' \
                > imx_rproc.c

              dtc -I dtb -O dts "$m7Dtb" > m7.dts
              grep -q 'compatible = "fsl,imx95-cm7"' m7.dts
              grep -q 'mbox-names = "tx", "rx", "rxdb"' m7.dts
              grep -q 'memory-region = ' m7.dts

              test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88000000 reg)" =                 "0 88000000 0 8000"
              test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88008000 reg)" =                 "0 88008000 0 8000"
              test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88010000 reg)" =                 "0 88010000 0 8000"
              test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88018000 reg)" =                 "0 88018000 0 8000"
              test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88020000 reg)" =                 "0 88020000 0 100000"
              test "$(fdtget -t x "$m7Dtb" /reserved-memory/memory@88220000 reg)" =                 "0 88220000 0 1000"

              set -- $(fdtget -t x "$m7Dtb" /imx95-cm7 mboxes)
              test "$#" -eq 9
              set -- $(fdtget -t x "$m7Dtb" /imx95-cm7 memory-region)
              test "$#" -eq 6

              grep -q                 '{ 0x00000000, 0x203C0000, 0x00040000, ATT_OWN | ATT_IOMEM }'                 imx_rproc.c
              grep -q                 '{ 0x20000000, 0x20400000, 0x00040000, ATT_OWN | ATT_IOMEM }'                 imx_rproc.c

              test $(( ${release.m7.remoteproc.tcm.code.systemAddress} + ${release.m7.remoteproc.tcm.code.size} ))                 -le $(( ${release.m7.remoteproc.tcm.data.systemAddress} ))
              test $(( ${m7Vring0.address} + ${m7Vring0.size} ))                 -le $(( ${m7Vring1.address} ))
              test $(( ${m7Vring1.address} + ${m7Vring1.size} ))                 -le $(( ${m7Vring2.address} ))
              test $(( ${m7Vring2.address} + ${m7Vring2.size} ))                 -le $(( ${m7Vring3.address} ))
              test $(( ${m7Vring3.address} + ${m7Vring3.size} ))                 -le $(( ${release.m7.remoteproc.sharedMemory.vdevBuffer.address} ))
              test $(( ${release.m7.remoteproc.sharedMemory.vdevBuffer.address} + ${release.m7.remoteproc.sharedMemory.vdevBuffer.size} ))                 -le $(( ${release.m7.remoteproc.sharedMemory.resourceTable.address} ))

              dtc -I dtb -O dts "$baselineDtb" > baseline.dts
              if grep -q 'compatible = "fsl,imx95-cm7"' baseline.dts; then
                echo "M7 remoteproc unexpectedly entered the baseline device tree" >&2
                exit 1
              fi

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

          source-sd-image-layout =
            pkgs.runCommand "frdm-imx95-source-sd-image-layout" {
              nativeBuildInputs = [
                pkgs.coreutils
                pkgs.util-linux
                pkgs.zstd
              ];
              allowSubstitutes = false;
              preferLocalBuild = true;
              meta = {
                license = configuredSourceBootContainer.providerLicense;
                hydraPlatforms = [];
              };
            } ''
              image=$(echo ${sourceSdImage}/sd-image/*.img.zst)
              zstd --decompress --stdout "$image" > image.img

              dd if=image.img bs=1 skip=${toString sourceBootContainerOffsetBytes} \
                count=${toString configuredSourceBootContainer.expectedSize} \
                status=none | \
                cmp - \
                  "${configuredSourceBootContainer}/${configuredSourceBootContainer.fileName}"

              firstStart=$(sfdisk --json image.img | \
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].start')
              test "$firstStart" -eq $(( ${toString firmwareOffsetBytes} / 512 ))
              test $(( ${toString sourceBootContainerOffsetBytes} + ${toString configuredSourceBootContainer.expectedSize} )) \
                -lt ${toString ubootEnvironmentOffsetBytes}

              mkdir "$out"
              sha256sum image.img > "$out/image.sha256"
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
              image=$(echo ${compatibilitySdImage}/sd-image/*.img.zst)
              zstd --decompress --stdout "$image" > image.img

              firstStart=$(sfdisk --json image.img |
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].start')
              secondStart=$(sfdisk --json image.img |
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[1].start')
              firstBootable=$(sfdisk --json image.img |
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[0].bootable')
              secondBootable=$(sfdisk --json image.img |
                ${lib.getExe pkgs.jq} -r '.partitiontable.partitions[1].bootable // false')

              test "$firstStart" -eq $(( ${toString firmwareOffsetBytes} / 512 ))
              test "$secondStart" -eq $(( ${toString rootOffsetBytes} / 512 ))
              test "$firstBootable" = true
              test "$secondBootable" = false

              dd if=image.img bs=1 skip=${toString compatibilityBootContainerOffsetBytes} \
                count=${toString compatibilityBoard.config.hardware.nxp.imx95.bootContainerSizeBytes} \
                status=none |
                cmp - \
                  "${compatibilityBootContainer}/${compatibilityBootContainerName}"

              dd if=image.img bs=1 skip=${toString compatibilityUbootEnvironmentOffsetBytes} \
                count=${toString compatibilityBoard.config.hardware.nxp.imx95.ubootEnvironmentSizeBytes} \
                status=none > uboot.env
              grep -a -q 'bootcmd=bootflow scan -lb' uboot.env
              grep -a -q 'boot_targets=mmc1 mmc0' uboot.env
              grep -a -q 'boot_prefixes=/' uboot.env
              grep -a -q 'fdt_addr_r=0x95000000' uboot.env
              grep -a -q 'ramdisk_addr_r=0x98000000' uboot.env

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
