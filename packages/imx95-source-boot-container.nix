{
  bash,
  buildInstance ? null,
  expectedBootContainerSha256 ? null,
  callPackage,
  coreutils,
  gawk,
  gnumake,
  gnused,
  lib,
  remoteprocMode ? false,
  runCommand,
  xxd,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  bootContainerConfig =
    if remoteprocMode
    then release.m7.remoteproc.bootContainer
    else {
      systemManagerConfig = release.machine.systemManagerConfig;
      systemManagerPolicy = "default";
      expectedSha256 = release.machine.bootContainerExpectedSha256;
      expectedSize = release.machine.bootContainerExpectedSize;
      fileName = release.machine.bootContainerFileName;
    };
  bootContainerExpectedSha256 =
    if expectedBootContainerSha256 == null
    then bootContainerConfig.expectedSha256
    else expectedBootContainerSha256;
  bootContainerExpectedHash = builtins.convertHash {
    hash = bootContainerExpectedSha256;
    hashAlgo = "sha256";
    toHashFormat = "sri";
  };
  uboot = callPackage ./uboot-imx95-frdm.nix {};
  armTrustedFirmware = callPackage ./imx-atf-imx95.nix {};
  optee = callPackage ./imx-optee-os-imx95.nix {};
  systemManager = callPackage ./imx-system-manager-imx95.nix {
    systemManagerConfig = bootContainerConfig.systemManagerConfig;
    inherit remoteprocMode;
  };
  oei = callPackage ./imx-oei-imx95-frdm.nix {};
  imxMkimage = callPackage ./imx-mkimage-imx95.nix {};
  licensedFirmware = callPackage ./imx95-licensed-firmware.nix {};
  eleMember = builtins.head release.licensedFirmware.ele.members;
  ddrMembers = builtins.listToAttrs (
    map (member: {
      name = member.fileName;
      value = member;
    })
    release.licensedFirmware.ddr.members
  );
  firmwareValidator = ../scripts/check-nxp-firmware-file;
  derivationName =
    "frdm-imx95-source-boot-container-${release.release.version}"
    + lib.optionalString remoteprocMode "-m7-remoteproc"
    + lib.optionalString (buildInstance != null) "-${buildInstance}";

  nxpLicense =
    lib.licenses.unfree
    // {
      inherit (release.licensedFirmware.license) fullName redistributable;
      url = "https://www.nxp.com/docs/en/disclaimer/LA_OPT_NXP_Software_License.pdf";
    };

  sourceComponents =
    map
    (component: {
      name = component.pname;
      kind = "source";
      repository = "https://github.com/${component.fetchFromGitHub.owner}/${component.fetchFromGitHub.repo}";
      inherit (component.fetchFromGitHub) rev sha256;
    })
    (builtins.attrValues release.sources);

  firmwareComponents =
    map
    (member: {
      name = member.fileName;
      kind = "licensed-binary-firmware";
      inherit (member) sha256 size;
    })
    (
      release.licensedFirmware.ele.members
      ++ release.licensedFirmware.ddr.members
    );
in
  runCommand derivationName {
    nativeBuildInputs = [
      coreutils
      gawk
      gnumake
      gnused
      xxd
    ];

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      inherit nxpLicense;
      releaseMapping = release;
      componentManifest = sourceComponents ++ firmwareComponents;
      containsM7Application = false;
      expectedHash = bootContainerExpectedHash;
      expectedSha256 = bootContainerExpectedSha256;
      expectedSize = bootContainerConfig.expectedSize;
      fileName = bootContainerConfig.fileName;
      systemManagerConfig = bootContainerConfig.systemManagerConfig;
      systemManagerPolicy = bootContainerConfig.systemManagerPolicy;
      providerKind = "source-assembled";
      providerLicense = nxpLicense;
      release = release.release.version;
      inherit (release.machine) bootContainerOffsetKiB reservedBootRegionMiB;
      ubootEnvironmentOffsetKiB = 7 * 1024;
      ubootEnvironmentSizeBytes = 16 * 1024;
    };

    meta = {
      description = "Source-assembled NXP LF boot container for the FRDM-i.MX95";
      homepage = release.release.metaImx.repository;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
      sourceProvenance = with lib.sourceTypes; [
        fromSource
        binaryFirmware
      ];
    };
  } ''
    check_open_component() {
      path="$1"
      if [ ! -s "$path" ]; then
        echo "required source-built component is missing or empty: $path" >&2
        exit 1
      fi
    }

    check_open_component "${uboot}/u-boot-spl.bin"
    check_open_component "${uboot}/u-boot.bin"
    check_open_component "${armTrustedFirmware}/bl31.bin"
    check_open_component "${optee}/${optee.artifacts.teeRaw}"
    check_open_component "${systemManager}/m33_image.bin"
    check_open_component "${oei}/oei-m33-ddr.bin"
    check_open_component "${imxMkimage}/${imxMkimage.assemblyRoot}/iMX95/soc.mak"

    ${bash}/bin/bash ${firmwareValidator} \
      "${licensedFirmware.ele}/${eleMember.fileName}" \
      "${eleMember.sha256}" \
      ${toString eleMember.size}
    ${bash}/bin/bash ${firmwareValidator} \
      "${licensedFirmware.lpddr4xDmem}/${ddrMembers."lpddr4x_dmem_v202409.bin".fileName}" \
      "${ddrMembers."lpddr4x_dmem_v202409.bin".sha256}" \
      ${toString ddrMembers."lpddr4x_dmem_v202409.bin".size}
    ${bash}/bin/bash ${firmwareValidator} \
      "${licensedFirmware.lpddr4xDmemQuickBoot}/${ddrMembers."lpddr4x_dmem_qb_v202409.bin".fileName}" \
      "${ddrMembers."lpddr4x_dmem_qb_v202409.bin".sha256}" \
      ${toString ddrMembers."lpddr4x_dmem_qb_v202409.bin".size}
    ${bash}/bin/bash ${firmwareValidator} \
      "${licensedFirmware.lpddr4xImem}/${ddrMembers."lpddr4x_imem_v202409.bin".fileName}" \
      "${ddrMembers."lpddr4x_imem_v202409.bin".sha256}" \
      ${toString ddrMembers."lpddr4x_imem_v202409.bin".size}
    ${bash}/bin/bash ${firmwareValidator} \
      "${licensedFirmware.lpddr4xImemQuickBoot}/${ddrMembers."lpddr4x_imem_qb_v202409.bin".fileName}" \
      "${ddrMembers."lpddr4x_imem_qb_v202409.bin".sha256}" \
      ${toString ddrMembers."lpddr4x_imem_qb_v202409.bin".size}

    cp -R "${imxMkimage}/${imxMkimage.assemblyRoot}" work
    chmod -R u+w work

    install -m0644 "${uboot}/u-boot-spl.bin" work/iMX95/u-boot-spl.bin
    install -m0644 "${uboot}/u-boot.bin" work/iMX95/u-boot.bin
    install -m0644 "${armTrustedFirmware}/bl31.bin" work/iMX95/bl31.bin
    install -m0644 "${optee}/${optee.artifacts.teeRaw}" work/iMX95/tee.bin
    install -m0644 "${systemManager}/m33_image.bin" work/iMX95/m33_image.bin
    install -m0644 "${oei}/oei-m33-ddr.bin" work/iMX95/oei-m33-ddr.bin
    install -m0644 \
      "${licensedFirmware.ele}/${eleMember.fileName}" \
      "work/iMX95/${eleMember.fileName}"
    install -m0644 \
      "${licensedFirmware.lpddr4xDmem}/${ddrMembers."lpddr4x_dmem_v202409.bin".fileName}" \
      "work/iMX95/${ddrMembers."lpddr4x_dmem_v202409.bin".fileName}"
    install -m0644 \
      "${licensedFirmware.lpddr4xDmemQuickBoot}/${ddrMembers."lpddr4x_dmem_qb_v202409.bin".fileName}" \
      "work/iMX95/${ddrMembers."lpddr4x_dmem_qb_v202409.bin".fileName}"
    install -m0644 \
      "${licensedFirmware.lpddr4xImem}/${ddrMembers."lpddr4x_imem_v202409.bin".fileName}" \
      "work/iMX95/${ddrMembers."lpddr4x_imem_v202409.bin".fileName}"
    install -m0644 \
      "${licensedFirmware.lpddr4xImemQuickBoot}/${ddrMembers."lpddr4x_imem_qb_v202409.bin".fileName}" \
      "work/iMX95/${ddrMembers."lpddr4x_imem_qb_v202409.bin".fileName}"

    make -C work/iMX95 \
      -f soc.mak \
      MKIMG=../mkimage_imx8 \
      REV=${release.machine.imxMkimageRevision} \
      TEE=tee.bin \
      OEI=YES \
      LPDDR_TYPE=${release.machine.ddrType} \
      dtbs=${release.machine.ubootDtb} \
      ${release.machine.imxMkimageTarget}

    if [ ! -s work/iMX95/flash.bin ]; then
      echo "imx-mkimage did not produce a non-empty flash.bin" >&2
      exit 1
    fi

    actual_size=$(stat -c %s work/iMX95/flash.bin)
    if [ "$actual_size" -ne ${toString bootContainerConfig.expectedSize} ]; then
      echo "assembled boot container has size $actual_size; expected ${toString bootContainerConfig.expectedSize}" >&2
      exit 1
    fi

    actual_sha256=$(sha256sum work/iMX95/flash.bin | cut -d' ' -f1)
    if [ "$actual_sha256" != ${bootContainerExpectedSha256} ]; then
      echo "assembled boot container identity mismatch" >&2
      echo "expected: ${bootContainerExpectedSha256}" >&2
      echo "actual:   $actual_sha256" >&2
      exit 1
    fi

    install -Dm0444 \
      work/iMX95/flash.bin \
      "$out/${bootContainerConfig.fileName}"
  ''
