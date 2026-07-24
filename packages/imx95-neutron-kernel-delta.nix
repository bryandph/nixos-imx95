{
  schemaVersion = 1;

  comparison = {
    upstream = {
      repository = "https://github.com/torvalds/linux";
      tag = "v7.1";
      rev = "8cd9520d35a6c38db6567e97dd93b1f11f185dc6";
    };
    nxpReference = {
      repository = "https://github.com/nxp-imx/linux-imx";
      branch = "lf-6.18.20-2.0.0";
      rev = "b096ce610e956cc2596006343df8a2a26ed6e019";
    };
  };

  fileDelta = {
    added = [
      {
        path = "drivers/staging/neutron/Kconfig";
        blobSha1 = "132aeab17d670e1f3282ef26415e1a19f9ea9de3";
        size = 394;
        category = "kconfig";
      }
      {
        path = "drivers/staging/neutron/Makefile";
        blobSha1 = "2f622acc333cc38ae6b4f9ce52ae7a9c8eb07644";
        size = 216;
        category = "build";
      }
      {
        path = "drivers/staging/neutron/neutron_buffer.c";
        blobSha1 = "79d4ab809bf40a26e0586f9f2e400f668a1bddf6";
        size = 5763;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_buffer.h";
        blobSha1 = "918eb28fd6a00297b1896feccd14833a4f5361b2";
        size = 1840;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_device.c";
        blobSha1 = "af74671e4178f813f2098a0efaf2d36d363fdc90";
        size = 22228;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_device.h";
        blobSha1 = "fc40b2d461f446323a4b5fb6531e22422d6b9132";
        size = 5552;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_driver.c";
        blobSha1 = "75f02ebc445658f25d9f2a290d75d65c525b39d9";
        size = 7152;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_inference.c";
        blobSha1 = "bd49a57a66b4eaecf7f4684e72698e2d171652d2";
        size = 13656;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_inference.h";
        blobSha1 = "db0419ab208031c65704de9cc062a0f6228db3be";
        size = 3579;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_mailbox.c";
        blobSha1 = "da167f2d7d6e8f8050332f5da8dd2f9cb4a51a55";
        size = 5959;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/neutron_mailbox.h";
        blobSha1 = "da88695e12435ef3fb9b2eae4ac75ee0dcb68d50";
        size = 1278;
        category = "driver";
      }
      {
        path = "drivers/staging/neutron/uapi/neutron.h";
        blobSha1 = "285ade234acfdfafe9164992f871593e7fadf236";
        size = 4569;
        category = "uapi";
      }
      {
        path = "drivers/remoteproc/imx_neutron_rproc.c";
        blobSha1 = "02ac5ae66e97bd4dba47d746754b5695e0dd2457";
        size = 7539;
        category = "remoteproc";
      }
      {
        path = "arch/arm64/boot/dts/freescale/imx95-19x19-evk-neutron.dtso";
        blobSha1 = "91b44a3050d7478c3d4ff5e11db8e6615aadeaf9";
        size = 347;
        category = "device-tree";
      }
    ];

    modified = [
      {
        path = "drivers/staging/Kconfig";
        nxpBlobSha1 = "43ef698939b09ad1180692fe688a15c362e5b091";
        category = "kconfig";
        purpose = "source drivers/staging/neutron/Kconfig";
      }
      {
        path = "drivers/staging/Makefile";
        nxpBlobSha1 = "e506d04dba55534f98a25ee49136f4c514a6c0ba";
        category = "build";
        purpose = "build drivers/staging/neutron";
      }
      {
        path = "drivers/remoteproc/Kconfig";
        nxpBlobSha1 = "acd30be039347f5bc99ea61f538e523918d90de5";
        category = "kconfig";
        purpose = "define IMX_NEUTRON_REMOTEPROC";
      }
      {
        path = "drivers/remoteproc/Makefile";
        nxpBlobSha1 = "6113ccb454de47e8d0399a64b92edf11fb5dd189";
        category = "build";
        purpose = "build imx_neutron_rproc.o";
      }
      {
        path = "arch/arm64/configs/imx_v8_defconfig";
        nxpBlobSha1 = "5cc0c5514dc0fd23a18a8c7fde4d60b123f8c158";
        category = "kernel-config";
        purpose = "select NEUTRON and IMX_NEUTRON_REMOTEPROC";
      }
      {
        path = "arch/arm64/boot/dts/freescale/Makefile";
        nxpBlobSha1 = "bb6bc733c7e5adc6d44d180ff8055ef46a3c47a4";
        category = "device-tree-build";
        purpose = "compose the Neutron overlay with i.MX95 board DTBs";
      }
      {
        path = "arch/arm64/boot/dts/freescale/imx95.dtsi";
        nxpBlobSha1 = "2b1d562c17ac585b85aa4973753e87d41a2782cd";
        category = "device-tree";
        purpose = "define Neutron remoteproc and accelerator resources";
      }
    ];
  };

  kernelConfig = {
    required = {
      NEUTRON = "y";
      IMX_NEUTRON_REMOTEPROC = "y";
      REMOTEPROC = "y";
      ARCH_MXC = "y";
    };
    dependencies = {
      NEUTRON = ["ARCH_MXC" "IMX_NEUTRON_REMOTEPROC"];
      IMX_NEUTRON_REMOTEPROC = ["ARCH_MXC" "REMOTEPROC"];
    };
  };

  deviceTree = {
    compatibles = {
      accelerator = "fsl,imx95-neutron";
      remoteproc = "fsl,imx95-neutron-rproc";
    };
    resources = {
      remoteproc = {
        address = "0x4ab00000";
        size = "0x4";
        powerDomain = "IMX95_PD_NPU";
      };
      accelerator = {
        address = "0x4ab00004";
        size = "0x400";
        interrupt = {
          controller = "GIC";
          type = "SPI";
          number = 318;
          trigger = "level-high";
        };
        clocks = [
          {
            provider = "scmi_clk";
            id = "IMX95_CLK_NPU";
            name = "npu";
          }
          {
            provider = "scmi_clk";
            id = "IMX95_CLK_NPUAPB";
            name = "npu_apb";
          }
        ];
        powerDomain = "IMX95_PD_NPU";
        iommu = {
          provider = "smmu";
          streamId = "0xd";
        };
        remoteprocPhandle = "neutron_core";
      };
      reservedMemory = {
        address = "0x100000000";
        size = "0x100000000";
        compatible = "shared-dma-pool";
        reusable = true;
        consumer = "neutron";
      };
    };
    binding = {
      path = null;
      status = "missing-from-nxp-reference";
      consequence = "the reduced provider must carry local structural assertions for every inventoried property";
    };
  };

  upstreamAbsence = {
    paths = [
      "drivers/staging/neutron"
      "drivers/remoteproc/imx_neutron_rproc.c"
      "arch/arm64/boot/dts/freescale/imx95-19x19-evk-neutron.dtso"
    ];
    configSymbols = [
      "NEUTRON"
      "IMX_NEUTRON_REMOTEPROC"
    ];
    compatibles = [
      "fsl,imx95-neutron"
      "fsl,imx95-neutron-rproc"
    ];
  };
}
