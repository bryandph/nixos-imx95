{inputs, ...}: {
  flake.modules.nixos.frdm-imx95-m7-remoteproc = {
    config,
    lib,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    m7BootContainer = inputs.self.packages.${system}.frdm-imx95-m7-source-boot-container;
    m7Ctl = inputs.self.packages.${system}.frdm-imx95-m7-ctl;
    m7SmokeFirmware = inputs.self.packages.${system}.frdm-imx95-m7-smoke;
    providerKind = config.boot.kernelPackages.kernel.providerKind or "upstream";
    usesCombinedNxpProvider = providerKind == "nxp-full-combined";
  in {
    hardware.nxp.imx95.bootContainer = lib.mkOverride 900 m7BootContainer;

    hardware.deviceTree.overlays = lib.mkIf (!usesCombinedNxpProvider) [
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

    hardware.firmware = [m7SmokeFirmware];
    environment.systemPackages = [m7Ctl];

    assertions = [
      {
        assertion =
          usesCombinedNxpProvider
          || (
            providerKind
            == "upstream"
            && lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.1"
          );
        message = ''
          FRDM-i.MX95 M7 remoteproc requires either upstream Linux 7.1 or
          newer, or the reviewed NXP combined provider with native
          fsl,imx95-cm7 support.
        '';
      }
    ];
  };
}
