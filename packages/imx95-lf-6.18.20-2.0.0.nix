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
        expectedSha256 = "0dd1b75a176c4135d744d708f8629842599aebc600ab9444e9509ccec82230a4";
        expectedSize = 2995200;
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
        "m7-local-wfi"
      ];
      excludedUntilLifecycleValidation = [
        "scmi-system-manager"
        "a55-suspend-wake"
        "rpmsg"
      ];
      powerPolicy = {
        m7LocalIdle = {
          enabled = true;
          mechanism = "cortex-m-wfi";
          wakeSource = "systick";
          affectsA55 = false;
        };
        a55SuspendWake = {
          enabled = false;
          rationale = "Linux/SRTM coordination and the System Manager wake contract are not validated";
          requiredPreconditions = [
            "linux-suspend-transaction"
            "system-manager-lm1-authorization"
            "a55-wake-source-armed"
            "out-of-band-recovery"
          ];
        };
      };
    };
  };

  neutron = {
    identityPolicy = {
      authority = "immutable revisions, Git blob identities, and published SHA-256 values";
      versionLabelsAreInformational = true;
      rationale = ''
        The release recipe calls the runtime 3.1.1 while the selected repository
        SBOM and matching machine-learning guide call the same stack 3.1.2.
        The pinned repository revision and member identities are authoritative;
        no package may infer content from either display version.
      '';
    };

    versionLabels = {
      recipe = "3.1.1";
      guide = "3.1.2";
      sbom = "3.1.2";
      selectedConverter = "3.1.2";
    };

    kernel = {
      nxpReference = {
        repository = "https://github.com/nxp-imx/linux-imx";
        branch = "lf-6.18.20-2.0.0";
        rev = "b096ce610e956cc2596006343df8a2a26ed6e019";
        fetchFromGitHub = {
          owner = "nxp-imx";
          repo = "linux-imx";
          rev = "b096ce610e956cc2596006343df8a2a26ed6e019";
          sha256 = "sha256-Dz+kh5GtUtBCocBTvkXN4Ql7p1ZjX+DVvChIRoYj6/w=";
        };
        license = lib.licenses.gpl2Only;
      };
      upstreamComparison = {
        repository = "https://github.com/torvalds/linux";
        tag = "v7.1";
        rev = "8cd9520d35a6c38db6567e97dd93b1f11f185dc6";
        boardDtsPath = "arch/arm64/boot/dts/freescale/imx95-15x15-frdm.dts";
      };
      delta = import ./imx95-neutron-kernel-delta.nix;
    };

    runtime = {
      repository = "https://github.com/nxp-imx/neutron";
      branch = "lf-6.18.20_2.0.0";
      rev = "d0ff138390aeba2b6c5169d8f0ca13f6a6b8219a";
      recipe = {
        path = "meta-imx-ml/recipes-libraries/neutron/neutron_3.1.1.bb";
        blobSha1 = "7f9f6100cedd5070832d098f95db35149a6ae909";
      };
      license = {
        name = "NXP Software License Agreement";
        free = false;
        redistributable = false;
        file = {
          path = "LICENSE.txt";
          blobSha1 = "37ddcbd5e3d163b6a5fe52fb0384d6b807c5dc64";
          size = 52051;
        };
        contentRegister = {
          path = "SW-Content-Register.txt";
          blobSha1 = "c76c4018ed8dac88efca1c72a7ee5bf9d83908bb";
          size = 2236;
        };
        conditionalDistribution = "Section 2.3 applies only to an authorized NXP-based system";
      };
      sbom = {
        path = "SBOM.spdx.json";
        blobSha1 = "29156bcde3cc7f1a4e433a13ea6cef7b667f514c";
        size = 135878;
      };
      members = {
        firmware = {
          path = "imx95/firmware/NeutronFirmware.elf";
          blobSha1 = "6696976e423992993313a8aa0c58c9d11c598cc7";
          size = 46388;
        };
        driver = {
          path = "imx95/library/libNeutronDriver.so";
          blobSha1 = "d21dfed5315033aec572ca4ce251be42f4aca65f";
          size = 68496;
        };
        headers = [
          {
            path = "imx95/include/NeutronDriver.h";
            blobSha1 = "36f295bc054245efd4f9815646be06e24fe11680";
            size = 8880;
          }
          {
            path = "imx95/include/NeutronErrors.h";
            blobSha1 = "20239555722192d8b0d760e948c111b33f9ff653";
            size = 2693;
          }
        ];
      };
    };

    tensorflowLite = {
      version = "2.19.0";
      repository = "https://github.com/nxp-imx/tensorflow-imx";
      branch = "lf-6.18.20_2.0.0";
      rev = "41cd35bea009fa11a7bceecfa1a9dcf3f9255628";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "tensorflow-imx";
        rev = "41cd35bea009fa11a7bceecfa1a9dcf3f9255628";
        sha256 = "188830dsgdshgd91d9qk4j0jwqnsc8ym2ask8nkb6zfl2fk940sl";
      };
      license = lib.licenses.asl20;
      licenseFile = {
        path = "LICENSE";
        blobSha1 = "12d255f8e0f049d3c3127e71788e219b86cdf55b";
      };
      sbom = {
        path = "SBOM.spdx.json";
        blobSha1 = "d8d7639ca2e2ae1e2e162c2c79581f12ee096e94";
      };
      recipe = {
        path = "meta-imx-ml/recipes-libraries/tensorflow-lite/tensorflow-lite-2.19.0.inc";
        blobSha1 = "c7870cafacd8b06085e0f533a50add69ba859bdb";
      };
    };

    delegate = {
      version = "2.19.0";
      repository = "https://github.com/nxp-imx/tflite-neutron-delegate";
      branch = "lf-6.18.20_2.0.0";
      rev = "4a38248c74b83b0b7f4f2a9091e095e1e92247d0";
      fetchFromGitHub = {
        owner = "nxp-imx";
        repo = "tflite-neutron-delegate";
        rev = "4a38248c74b83b0b7f4f2a9091e095e1e92247d0";
        sha256 = "1c2hmsjpqvkn9faqmn2ln356pfcn0l2zhkxk3v3cgdsczmx34jbn";
      };
      license = lib.licenses.asl20;
      licenseFile = {
        path = "LICENSE.txt";
        blobSha1 = "261eeb9e9f8b2b4b0d119366dda99c6fd7d35c64";
      };
      sbom = {
        path = "SBOM.spdx.json";
        blobSha1 = "9ffbaf090de879b8782ea36e1146e4a93dc227e5";
      };
      recipe = {
        path = "meta-imx-ml/recipes-libraries/tensorflow-lite/tensorflow-lite-neutron-delegate_2.19.0.bbappend";
        blobSha1 = "ea43a7615a3eba2efa202ad015bb048c2cb5d50f";
      };
    };

    converter = {
      package = "eiq-neutron-sdk";
      version = "3.1.2";
      pythonAbi = "cp311-cp311";
      platform = "manylinux_2_31_x86_64";
      index = "https://eiq.nxp.com/repository/eiq-neutron-sdk/";
      file = "eiq_neutron_sdk-3.1.2-cp311-cp311-manylinux_2_31_x86_64.whl";
      sha256 = "adf64e34d116292038321dd14a7e38153a191f915850de6a14337304293878fe";
      metadataSha256 = "4f364ee3f5d5fd382fd6168551c026b1c2e2e756215406816e8c36431c78d8ab";
      licenseReview = {
        reviewedOn = "2026-07-24";
        status = "no-affirmative-redistribution-authority";
        authorities = [
          "https://www.nxp.com/design/design-center/software/eiq-ai-development-environment/eiq-toolkit-for-end-to-end-model-development-and-deployment:EIQ-TOOLKIT"
          "https://eiq.nxp.com/learning-hub/tools/neutronSdk/softwareTools/NeutronConverter.html"
        ];
        rationale = ''
          NXP publishes the matched SDK as an account/license-acceptance
          download and documents how the converter embeds target-specific
          kernels into i.MX95 NeutronGraph containers. Neither reviewed
          authority grants redistribution rights for the tool or generated
          target payload. The wheel and every converted model therefore remain
          operator-supplied pending an affirmative grant.
        '';
      };
      convertedOutputRedistribution = "unresolved-operator-input";
    };

    model = {
      name = "mobilenet_v1_1.0_224_quant";
      sourceArchive = {
        url = "https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224_quant.tgz";
        sha256 = "0rj1fj8zcm9507rwxkg4vwk75kvi1ihb06i8ssr3dabkhv93496k";
        member = "mobilenet_v1_1.0_224_quant.tflite";
        memberSha256 = "ecc3a67c47c5a609ec35f6a58a7d97532834e43df4cb7d3f1204a8164b7d20dd";
        license = lib.licenses.asl20;
        licenseAuthority = "https://github.com/tensorflow/models";
      };
      converted = {
        target = "imx95";
        forceDeterminism = true;
        distribution = "operator-supplied-until-license-review";
        sha256 = "946a912f68b1d8d85ce33911287cdc3eedaf4cdbd1b102d7ba0c125c65a0e9ba";
        identity = "sha256:946a912f68b1d8d85ce33911287cdc3eedaf4cdbd1b102d7ba0c125c65a0e9ba";
      };
    };
  };

  multimedia = {
    release = "6.18.20-2.0.0";

    mainline = {
      kernel = {
        sourceAuthority = "neutron.kernel.upstreamComparison";
        requiredVersion = "7.0";
        boardDtb = "freescale/imx95-15x15-frdm.dtb";
      };
      gpu = {
        kernelDriver = "panthor";
        kernelSourcePath = "drivers/gpu/drm/panthor";
        deviceTreeCompatible = [
          "nxp,imx95-mali"
          "arm,mali-valhall-csf"
        ];
        userspace = "mesa";
        renderer = "Mali-G310";
        vulkanDriver = "PanVK";
        firmware = {
          source = "linux-firmware";
          memberFamily = "arm/mali/arch10.8";
        };
      };
      jpeg = {
        driver = "mxc-jpeg";
        kernelSourcePath = "drivers/media/platform/nxp/imx-jpeg";
        userspace = "v4l2";
        requiredRoles = [
          "encoder"
          "decoder"
        ];
        formats = {
          compressed = "JPEG";
          smokeRaw = "BGR3";
        };
      };
    };

    wave6 = {
      kernelDelta = import ./imx95-wave6-kernel-delta.nix;
      firmware = {
        distributionAuthority = "licensedFirmware.ddr.distribution";
        recipe = {
          repositoryAuthority = "release.metaImx";
          path = "meta-imx-bsp/recipes-bsp/firmware-imx/firmware-imx_8.32.bb";
        };
        license = {
          fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
          additionalDistributionSection = "2.3";
          redistributable = false;
        };
        member = {
          fileName = "wave633c_codec_fw.bin";
          archivePath = "firmware-imx-8.32-1991416/firmware/vpu/wave633c_codec_fw.bin";
          installPath = "wave633c_codec_fw.bin";
          installPaths = ["wave633c_codec_fw.bin"];
          identity = "derived-from-fixed-distribution";
          identityRationale = ''
            The exact member hash and size have not been inspected by an
            operator. The enclosing distribution has a fixed identity and the
            package selects this single release-recipe member. Do not invent a
            member identity; add one only after licensed local inspection.
          '';
        };
        localImport = {
          storePayload = "complete-fixed-distribution";
          packageOutput = "selected-member-only";
          runtimeClosureContainsDistribution = false;
          rationale = ''
            The standalone member hash and size are not yet available, so the
            declarative requireFile boundary must identify the complete
            operator-accepted distribution. The helper therefore adds that
            fixed distribution to the local store as a build source. The
            firmware derivation copies only the selected member; its output
            contains no store-path reference to the source distribution, so
            systems and images close over only the member package.
          '';
        };
        publicationPolicy = {
          allowSubstitutes = false;
          hydra = false;
          preferLocalBuild = true;
          publicCache = false;
          publicImage = false;
          publicRelease = false;
        };
      };
      userspace = {
        interface = "v4l2-mem2mem";
        probe = "v4l2-ctl";
        expectedDriver = "wave6";
        smokeFrame = {
          width = 256;
          height = 128;
          pixelFormat = "NV12";
          bytes = 49152;
        };
        codecs = [
          "H264"
          "HEVC"
        ];
      };
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
