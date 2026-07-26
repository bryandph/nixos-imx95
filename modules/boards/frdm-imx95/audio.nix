{inputs, ...}: {
  flake.modules.nixos.frdm-imx95-audio = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    audioSmoke = inputs.self.packages.${system}.frdm-imx95-audio-smoke;
    kernel = config.boot.kernelPackages.kernel;
    providerKind = kernel.providerKind or "upstream";
  in {
    users.groups.audio = {};
    environment.systemPackages = [
      audioSmoke
      pkgs.alsa-utils
    ];
    system.build.audioSmoke = audioSmoke;

    assertions = [
      {
        assertion =
          providerKind
          != "nxp-full-combined"
          || builtins.elem "audio" kernel.capabilities;
        message = "The combined NXP kernel must advertise the FRDM audio capability.";
      }
    ];
  };
}
