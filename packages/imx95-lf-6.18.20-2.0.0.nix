{lib}: {
  release = {
    version = "6.18.20-2.0.0";
    metaImx = {
      repository = "https://github.com/nxp-imx/meta-imx";
      branch = "wrynose-6.18.20-2.0.0";
      rev = "5bde00498b041167629890563478eb89c7ca10b8";
      machineFile = "meta-imx-bsp/conf/machine/imx95-15x15-lpddr4x-frdm.conf";
    };
    metaFreescale = {
      repository = "https://github.com/Freescale/meta-freescale";
      branch = "wrynose";
      rev = "381158b2010cb9c450c24ac2dc72afcb1536d54e";
      machineInclude = "conf/machine/include/imx95-evk.inc";
    };
  };

  machine = {
    name = "imx95-15x15-lpddr4x-frdm";
    soc = "iMX95";
    socRevision = "B0";
    ubootDefconfig = "imx95_15x15_frdm_defconfig";
    ubootDtb = "imx95-15x15-frdm.dtb";
    atfPlatform = "imx95";
    opteePlatform = "imx-mx95evk";
    opteePlatformFlavor = "mx95evk";
    systemManagerConfig = "mx95evk";
    systemManagerMonitorMode = "2";
    systemManagerImage = "m33_image.bin";
    oeiCore = "m33";
    oeiSoc = "mx95";
    oeiBoard = "mx95lp4x-15";
    oeiConfig = "ddr";
    oeiDdrConfig = "MIMX95_LPDDR4X_EVK_15X15_4000MTS_FW2024.09_timing";
    ddrType = "lpddr4x";
    imxMkimageTarget = "flash_a55";
    imxMkimageSoc = "iMX95";
    imxMkimageRevision = "B0";
    bootContainerFileName = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55";
    bootContainerExpectedHash = "sha256-5s1YjWQg/daHJI2gwb1A7JR539qJWhuqfo8SM821g5g=";
    bootContainerExpectedSha256 = "e6cd588d6420fdd687248da0c1bd40ec9479dfda895a1baa7e8f1233cdb58398";
    bootContainerExpectedSize = 2997248;
    bootContainerOffsetKiB = 32;
    reservedBootRegionMiB = 8;
  };

  toolchains = {
    aarch64 = {
      nixpkgsPackage = "pkgsCross.aarch64-multiplatform";
      targetPrefix = "aarch64-unknown-linux-gnu-";
    };
    armBareMetal = {
      nixpkgsPackage = "gcc-arm-embedded";
      version = "15.2.rel1";
      targetPrefix = "arm-none-eabi-";
      rationale = ''
        NXP's System Manager and OEI release sources require Arm GNU
        Toolchain 15.2.Rel1 as a matched compiler/binutils distribution.
        Nixpkgs' independently composed pkgsCross.arm-embedded toolchain
        links these images incorrectly, so use Nixpkgs' narrowly scoped,
        release-matched gcc-arm-embedded package for these two components.
      '';
    };
  };

  m7 = {
    manifest = {
      repository = "https://github.com/nxp-mcuxpresso/mcuxsdk-manifests";
      tag = "v26.06.00-LTS";
      rev = "b01ab9032249f0d10cf6791ee4d7de45dfb19166";
    };
    sourceReferences = {
      examples = {
        repository = "https://github.com/nxp-mcuxpresso/mcuxsdk-examples";
        rev = "37b89171f47d36e2e71eec730e2353d2c2986f04";
        license = lib.licenses.bsd3;
        applicationPath = "demo_apps/power_mode_switch_imx95/power_mode_switch.c";
        boardPath = "_boards/frdmimx95/demo_apps/power_mode_switch/cm7";
      };
      core = {
        repository = "https://github.com/nxp-mcuxpresso/mcuxsdk-core";
        rev = "a910e7645d2d809a3431e1d5f42fca1cdeee69c9";
        license = lib.licenses.bsd3;
      };
      devices = {
        repository = "https://github.com/nxp-mcuxpresso/mcux-devices-imx";
        rev = "e8e41cc8dca0f2616e34c5c8a7990b1567a0242f";
        license = lib.licenses.bsd3;
        deviceHeaderPath = "i.MX95/MIMX9596/MIMX9596_cm7_COMMON.h";
        lpuartRegisterHeaderPath = "i.MX95/periph/PERI_LPUART.h";
      };
    };
    remoteproc = {
      upstream = {
        repository = "https://github.com/torvalds/linux";
        tag = "v7.1";
        rev = "8cd9520d35a6c38db6567e97dd93b1f11f185dc6";
        driverPath = "drivers/remoteproc/imx_rproc.c";
        bindingPath = "Documentation/devicetree/bindings/remoteproc/fsl,imx-rproc.yaml";
      };
      nxpReference = {
        repository = "https://github.com/nxp-imx/linux-imx";
        branch = "lf-6.18.20-2.0.0";
        rev = "b096ce610e956cc2596006343df8a2a26ed6e019";
        boardDtsPath = "arch/arm64/boot/dts/freescale/imx95-15x15-frdm.dts";
        rpmsgDtsPath = "arch/arm64/boot/dts/freescale/imx95-15x15-frdm-rpmsg.dts";
      };
      compatible = "fsl,imx95-cm7";
      bootContainer = {
        systemManagerConfig = "mx95evk";
        systemManagerPolicy = "m7-remoteproc-lmm";
        expectedSha256 = "3edd7709521907d96d6b0dc91e401d79027738e96f3e7a0802563c5c206d0081";
        expectedSize = 2997248;
        fileName = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_a55-m7-remoteproc";
      };
      firmwareFormat = "elf32-littlearm";
      vendorDemoFormat = "raw-binary";
      tcm = {
        code = {
          deviceAddress = "0x00000000";
          systemAddress = "0x203c0000";
          size = "0x00040000";
        };
        data = {
          deviceAddress = "0x20000000";
          systemAddress = "0x20400000";
          size = "0x00040000";
        };
      };
      mailbox = {
        controller = "mu7";
        channels = [
          "tx:0:1"
          "rx:1:1"
          "rxdb:3:1"
        ];
      };
      sharedMemory = {
        vdevBuffer = {
          address = "0x88020000";
          size = "0x00100000";
        };
        vrings = [
          {
            address = "0x88000000";
            size = "0x00008000";
          }
          {
            address = "0x88008000";
            size = "0x00008000";
          }
          {
            address = "0x88010000";
            size = "0x00008000";
          }
          {
            address = "0x88018000";
            size = "0x00008000";
          }
        ];
        resourceTable = {
          address = "0x88220000";
          size = "0x00001000";
        };
      };
      baseline = {
        driverSupported = true;
        sharedMemoryReserved = true;
        mu7Enabled = true;
        cm7NodePresent = false;
      };
      deferredRpmsgOwnership = {
        ddrCarveout = {
          address = "0x80000000";
          size = "0x01000000";
        };
        disables = [
          "edma1"
          "edma2"
        ];
      };
    };
    publicDemo = {
      license = "MIT";
      firstSlice = [
        "cortex-m-runtime"
        "embassy-executor"
        "lpuart3-output"
        "systick-heartbeat"
      ];
      excludedUntilLifecycleValidation = [
        "m7-low-power"
        "scmi-system-manager"
        "a55-suspend-wake"
        "rpmsg"
      ];
    };
  };

  sources = {
    uboot = {
      pname = "uboot-imx95-frdm";
      version = "2026.04-lf-6.18.20-2.0.0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "uboot-imx";
        rev = "6eeef838dac4ddbc06ff14450531a95e8c5cb346";
        sha256 = "1vjhk4dd1wnfapc3133k3f8r2z64bg4z609pgrw9bkdcabr6bq8k";
      };
      branch = "lf_v2026.04";
      license = lib.licenses.gpl2Plus;
      licenseFile = "Licenses/gpl-2.0.txt";
      build = {
        target = "all";
        flags = [
          "CROSS_COMPILE=aarch64-unknown-linux-gnu-"
          "DTC=dtc"
        ];
      };
    };

    armTrustedFirmware = {
      pname = "imx-atf-imx95";
      version = "2.14-lf-6.18.20-2.0.0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "imx-atf";
        rev = "0779f89a5475a03193f7707f3bbb50cec11707c0";
        sha256 = "1yi0kkx9kr2qs7xd3bkcbpv8pizlbigprcing96i36fvri7ch9yx";
      };
      branch = "lf_v2.14";
      license = lib.licenses.bsd3;
      licenseFile = "license.rst";
      build = {
        target = "bl31";
        flags = [
          "PLAT=imx95"
          "SPD=opteed"
        ];
      };
    };

    optee = {
      pname = "imx-optee-os-imx95";
      version = "4.10.0-lf-6.18.20-2.0.0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "imx-optee-os";
        rev = "37c7fbf84c40eb9e5828532972ffb133b4917390";
        sha256 = "0gdf0sldvzrzrh7hijy9wr4jr5f98982wg4vxwjnjn75kanfwxid";
      };
      branch = "lf-6.18.20_2.0.0";
      license = lib.licenses.bsd2;
      licenseFile = "LICENSE";
      build = {
        target = "all";
        artifact = "tee-raw.bin";
        flags = [
          "PLATFORM=imx"
          "PLATFORM_FLAVOR=mx95evk"
          "CFG_TEE_TA_LOG_LEVEL=0"
          "CFG_TEE_CORE_LOG_LEVEL=0"
        ];
      };
    };

    systemManager = {
      pname = "imx-system-manager-imx95";
      version = "2026q2-lf-6.18.20-2.0.0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "imx-sm";
        rev = "44f76dcb32945a60e08ea0133700b820349efbd3";
        sha256 = "0lrlxpq3zxv726bldabgs9ypwvfjp68cvmdas3i5w5s3yq82216w";
      };
      branch = "master";
      license = lib.licenses.bsd3;
      licenseFile = "LICENSE.txt";
      build = {
        target = "all";
        flags = [
          "CONFIG=mx95evk"
          "M=2"
          "SM_CROSS_COMPILE=arm-none-eabi-"
        ];
      };
    };

    oei = {
      pname = "imx-oei-imx95-frdm";
      version = "1.0.0-lf-6.18.20-2.0.0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "imx-oei";
        rev = "e9bce6f4f69dceaf3664b7e28eb4302004ee0361";
        sha256 = "16b3aj62h2brlgkybhndd35bdsppd7xymm8yxbmx942ixizrq161";
      };
      branch = "master";
      license = lib.licenses.bsd3;
      licenseFile = "LICENSE.txt";
      build = {
        target = "all";
        flags = [
          "oei=ddr"
          "board=mx95lp4x-15"
          "DDR_CONFIG=MIMX95_LPDDR4X_EVK_15X15_4000MTS_FW2024.09_timing"
          "DEBUG=1"
          "OEI_CROSS_COMPILE=arm-none-eabi-"
          "r=B0"
        ];
      };
    };

    imxMkimage = {
      pname = "imx-mkimage-imx95";
      version = "6.18.20-2.0.0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "imx-mkimage";
        rev = "1b577853ae1afe1f26cdef27548da52fb424af48";
        sha256 = "12rpr2q99fcc7127rpr3j492bj8ddh7566yi24112jgzaj7xd17d";
      };
      branch = "lf-6.18.20_2.0.0";
      license = lib.licenses.gpl2Only;
      licenseFile = "LICENSE";
      build = {
        target = "flash_a55";
        flags = [
          "SOC=iMX95"
          "REV=B0"
          "TEE=tee.bin"
          "OEI=YES"
          "LPDDR_TYPE=lpddr4x"
          "dtbs=imx95-15x15-frdm.dtb"
        ];
      };
    };
  };

  licensedFirmware = {
    license = {
      fullName = "NXP Software License Agreement";
      redistributable = false;
    };

    ele = {
      distribution = {
        fileName = "firmware-ele-imx-2.0.6-c0b284c.bin";
        sha256 = "ff42b838c42448616d3f6dc5a7f0d47c207bb0bae1ae00bea091103ed4012c28";
      };
      members = [
        {
          fileName = "mx95b0-ahab-container.img";
          sha256 = "43baad07d08789e91a6d956f5071257fb4680be5fbcfeca2af0a33ff5009f53c";
          size = 175488;
        }
      ];
    };

    m7PowerModeDemo = {
      distribution = {
        fileName = "LF_v6.18.20-2.0.0_images_IMX95EVK.zip";
        sha256 = "76149ba07ae8a42e32a52a461f21d90c88ef44f1a6f79de7b7afe85536a1e903";
        size = 4779306360;
      };
      member = {
        fileName = "imx95-15x15-frdm_m7_TCM_power_mode_switch.bin";
        archivePath = "imx_mcore_demos/imx95-15x15-frdm_m7_TCM_power_mode_switch.bin";
        sha256 = "15141ba5c66504131b45c5daf29f2cf1a75273cff8f18f0cc205aa3a4d57cdb9";
        size = 35916;
      };
      provenance = {
        sourceCompositionReportPackage = "imx95-m7-demo-26.06.00.bin";
        outgoingLicense = "LA_OPT_NXP_Software_License v63 May 2025";
        additionalDistributionSection = "2.3";
        redistributable = false;
      };
    };

    ddr = {
      distribution = {
        fileName = "firmware-imx-8.32-1991416.bin";
        sha256 = "11396e5798b62cd61963db806c0c05500887bc62a98e1d16dbc3014aa0c21a2a";
      };
      members = [
        {
          fileName = "lpddr4x_dmem_v202409.bin";
          sha256 = "1e770d3f0f0d9fd7a4be7d8a9ba69db60a1239088f3f2ea38c1944564cb89d6b";
          size = 65536;
        }
        {
          fileName = "lpddr4x_dmem_qb_v202409.bin";
          sha256 = "b9344aa7a64c7df6a537315dbbafc4dc4b84bb0a73fea7a798c059d7c1d236ac";
          size = 65536;
        }
        {
          fileName = "lpddr4x_imem_v202409.bin";
          sha256 = "8625bd4bdfaccdf773469a7f81d8ae270e7a7ec4a451cbf4b90f8bbc4dc2398a";
          size = 51860;
        }
        {
          fileName = "lpddr4x_imem_qb_v202409.bin";
          sha256 = "93946e2ed414889c0ab47899c201833bc1807cb367e5e3130a11c0bc1f58edb5";
          size = 25224;
        }
      ];
    };
  };
}
