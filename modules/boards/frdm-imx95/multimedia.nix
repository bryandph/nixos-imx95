{
  inputs,
  lib,
  ...
}: {
  flake.modules.nixos.frdm-imx95-multimedia = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    release = import ../../../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
    gpuSmoke = inputs.self.packages.${system}.frdm-imx95-gpu-smoke;
    jpegSmoke = inputs.self.packages.${system}.frdm-imx95-jpeg-smoke;
  in {
    hardware.graphics.enable = true;
    users.groups.video = {};
    services.udev.extraRules = ''
      SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", ATTR{name}=="mxc-jpeg*", GROUP="video", MODE="0660"
    '';
    environment.systemPackages = [
      gpuSmoke
      jpegSmoke
      pkgs.v4l-utils
      pkgs.vulkan-tools
    ];
    system.build = {
      inherit gpuSmoke jpegSmoke;
    };
    assertions = [
      {
        assertion =
          (config.boot.kernelPackages.kernel.providerKind or "upstream")
          == "upstream";
        message = "Mainline multimedia must retain the upstream kernel provider.";
      }
      {
        assertion = release.multimedia.mainline.gpu.userspace == "mesa";
        message = "Mainline multimedia must use the open Mesa userspace.";
      }
    ];
  };
}
