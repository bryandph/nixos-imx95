{
  inputs,
  lib,
  ...
}: {
  flake.modules.nixos.frdm-imx95-neutron-npu = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.hardware.nxp.imx95.neutron;
    system = pkgs.stdenv.hostPlatform.system;
    release = import ../../../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
    kernel = inputs.self.packages.${system}.linux-imx95-neutron-reduced;
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
    tensorflowLite = inputs.self.packages.${system}.tensorflow-lite-imx95;
    delegateSource = inputs.self.packages.${system}.tflite-neutron-delegate-source;
    modelSource = inputs.self.packages.${system}.imx95-neutron-model-source;
    smokeRunner = inputs.self.packages.${system}.frdm-imx95-neutron-smoke-runner;
    runtime = pkgs.callPackage ../../../packages/imx95-neutron-runtime.nix {
      runtimeRoot = cfg.runtimeRoot;
    };
    delegate = pkgs.callPackage ../../../packages/tflite-neutron-delegate-imx95.nix {
      inherit runtime tensorflowLite;
      source = delegateSource;
    };
    convertedModel =
      pkgs.runCommand "imx95-neutron-converted-model" {
        src = cfg.convertedModel;
        allowSubstitutes = false;
        preferLocalBuild = true;
        meta = {
          license = runtime.meta.license;
          hydraPlatforms = [];
          platforms = ["aarch64-linux"];
        };
        passthru.publicationPolicy = runtime.publicationPolicy;
      } ''
        test -f "$src"
        test "$(sha256sum "$src" | cut -d' ' -f1)" = \
          ${lib.escapeShellArg cfg.convertedModelSha256}
        install -Dm0444 "$src" "$out/share/models/${release.neutron.model.name}-neutron.tflite"
      '';
    deviceTreePackage = pkgs.runCommand "frdm-imx95-neutron-device-tree" {} ''
      install -Dm0444 \
        ${kernel}/dtbs/${kernel.neutronDtb} \
        "$out/freescale/imx95-15x15-frdm.dtb"
    '';
    smoke = pkgs.writeShellApplication {
      name = "frdm-imx95-neutron-smoke";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        export NEUTRON_BENCHMARK=${tensorflowLite}/bin/benchmark_model_dynamic
        export NEUTRON_CPU_MODEL=${modelSource}/${modelSource.modelPath}
        export NEUTRON_DELEGATE=${delegate}/lib/libneutron_delegate.so
        export NEUTRON_MODEL=${convertedModel}/share/models/${release.neutron.model.name}-neutron.tflite
        export NEUTRON_DEVICE=/dev/neutron0
        export NEUTRON_FIRMWARE=/run/current-system/firmware/NeutronFirmware.elf
        export NEUTRON_PERF_COUNTERS=/sys/kernel/debug/neutron/perf_counters
        export NEUTRON_REPORT="''${NEUTRON_REPORT:-$PWD/frdm-imx95-neutron-smoke.json}"
        exec ${lib.getExe smokeRunner} --require-char-device "$@"
      '';
      derivationArgs = {
        allowSubstitutes = false;
        preferLocalBuild = true;
      };
      passthru.publicationPolicy = runtime.publicationPolicy;
      meta = {
        description = "Licensed FRDM-i.MX95 Neutron acceptance smoke closure";
        license = runtime.meta.license;
        hydraPlatforms = [];
        platforms = ["aarch64-linux"];
      };
    };
  in {
    options.hardware.nxp.imx95.neutron = {
      runtimeRoot = lib.mkOption {
        type = lib.types.path;
        description = "Local store path produced by import-imx95-neutron-runtime.";
      };
      convertedModel = lib.mkOption {
        type = lib.types.path;
        description = "Local converted TFLite model produced by convert-imx95-neutron-model.";
      };
      convertedModelSha256 = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{64}";
        description = "Reviewed two-pass SHA-256 identity of the converted model.";
      };
    };

    config = {
      boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor nixosKernel);
      hardware.deviceTree.package = lib.mkForce deviceTreePackage;
      hardware.firmware = [runtime];
      hardware.firmwareCompression = "none";

      users.groups.neutron = {};
      services.udev.extraRules = ''
        SUBSYSTEM=="neutron", KERNEL=="neutron[0-9]*", GROUP="neutron", MODE="0660"
      '';
      systemd.tmpfiles.rules = [
        "z /sys/kernel/debug 0710 root neutron - -"
        "z /sys/kernel/debug/neutron 0750 root neutron - -"
        "z /sys/kernel/debug/neutron/perf_counters 0640 root neutron - -"
      ];

      environment.systemPackages = [
        delegate
        smoke
        tensorflowLite
      ];

      system.build = {
        inherit convertedModel delegate deviceTreePackage runtime smoke;
      };

      assertions = [
        {
          assertion = config.hardware.deviceTree.name == "freescale/imx95-15x15-frdm.dtb";
          message = "The Neutron role must preserve the accepted FRDM DT filename.";
        }
        {
          assertion = kernel.providerKind == "reduced-mainline";
          message = "The Neutron role must use the provider selected by identical checks.";
        }
      ];
    };
  };
}
