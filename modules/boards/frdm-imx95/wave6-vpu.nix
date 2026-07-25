{
  inputs,
  lib,
  ...
}: {
  flake.modules.nixos.frdm-imx95-wave6-vpu = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    release = import ../../../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
    delta = release.multimedia.wave6.kernelDelta;
    kernel = inputs.self.packages.${system}.linux-imx95-wave6;
    nixosKernel =
      kernel
      // {
        override = override:
          kernel.kernelOverride (
            if builtins.isFunction override
            then
              override {
                features = kernel.features;
                kernelPatches = kernel.kernelPatches;
                randstructSeed = "";
              }
            else override
          );
      };
    firmware = pkgs.callPackage ../../../packages/nxp-imx95-wave6-firmware.nix {};
    smoke = inputs.self.packages.${system}.frdm-imx95-wave6-smoke;
    deviceTreePackage = pkgs.runCommand "frdm-imx95-wave6-device-tree" {} ''
      install -Dm0444 \
        ${kernel}/dtbs/${kernel.wave6Dtb} \
        "$out/freescale/imx95-15x15-frdm.dtb"
    '';
  in {
    options.hardware.nxp.imx95.wave6 = {
      providerKind = lib.mkOption {
        type = lib.types.enum ["full-nxp-reference"];
        readOnly = true;
        description = "Evidence-selected release-pinned Wave6 kernel provider.";
      };
      firmwareMember = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Only licensed firmware member installed by the Wave6 role.";
      };
    };

    config = {
      hardware.nxp.imx95.wave6 = {
        providerKind = delta.providerSelection.selected;
        firmwareMember = release.multimedia.wave6.firmware.member.fileName;
      };
      boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor nixosKernel);
      hardware.deviceTree.package = lib.mkForce deviceTreePackage;
      hardware.firmware = [firmware];
      hardware.firmwareCompression = "none";
      users.groups.video = {};
      services.udev.extraRules = ''
        SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", DRIVERS=="wave6-vpu", GROUP="video", MODE="0660"
      '';
      environment.systemPackages = [
        smoke
        pkgs.v4l-utils
      ];
      system.build = {
        inherit deviceTreePackage firmware smoke;
      };
      assertions = [
        {
          assertion = kernel.providerKind == delta.providerSelection.selected;
          message = "Wave6 must use the explicitly selected release provider.";
        }
        {
          assertion =
            config.hardware.deviceTree.name
            == delta.deviceTree.selectedDtb;
          message = "Wave6 must preserve the accepted FRDM DT filename.";
        }
        {
          assertion = firmware.meta.license.redistributable == false;
          message = "Wave6 firmware must remain non-redistributable.";
        }
        {
          assertion = firmware.allowSubstitutes == false;
          message = "Wave6 firmware must not be substituted.";
        }
      ];
    };
  };
}
