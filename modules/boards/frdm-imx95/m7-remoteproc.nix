{...}: {
  flake.modules.nixos.frdm-imx95-m7-remoteproc = {
    config,
    lib,
    ...
  }: {
    hardware.deviceTree.overlays = [
      {
        name = "frdm-imx95-m7-remoteproc";
        filter = "imx95-15x15-frdm.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
            compatible = "fsl,imx95-15x15-frdm";

            fragment@0 {
              target-path = "/";

              __overlay__ {
                imx95-cm7 {
                  compatible = "fsl,imx95-cm7";
                  mbox-names = "tx", "rx", "rxdb";
                  mboxes = <&mu7 0 1>,
                            <&mu7 1 1>,
                            <&mu7 3 1>;
                  memory-region = <&vdevbuffer>,
                                  <&vdev0vring0>,
                                  <&vdev0vring1>,
                                  <&vdev1vring0>,
                                  <&vdev1vring1>,
                                  <&rsc_table>;
                  status = "okay";
                };
              };
            };
          };
        '';
      }
    ];

    assertions = [
      {
        assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.1";
        message = ''
          FRDM-i.MX95 M7 remoteproc requires Linux 7.1 or newer for the
          upstream fsl,imx95-cm7 driver and device-tree binding.
        '';
      }
    ];
  };
}
