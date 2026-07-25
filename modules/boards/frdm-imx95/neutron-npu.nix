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
    system = pkgs.stdenv.hostPlatform.system;
    release = import ../../../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
    kernel = inputs.self.packages.${system}.linux-imx95-neutron-reduced;
    providerKind = config.boot.kernelPackages.kernel.providerKind or "upstream";
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
    runtime = pkgs.callPackage ../../../packages/imx95-neutron-runtime.nix {};
    delegate = pkgs.callPackage ../../../packages/tflite-neutron-delegate-imx95.nix {
      inherit runtime tensorflowLite;
      source = delegateSource;
    };
    convertedModelSource = pkgs.requireFile {
      name = release.neutron.model.converted.fileName;
      sha256 = release.neutron.model.converted.sha256;
      message = ''
        ${release.neutron.model.converted.fileName} is an NXP eIQ Neutron SDK
        converted model and cannot be downloaded by this flake or redistributed
        through its public repository.

        Follow the two-pass conversion and import procedure documented in the
        Neutron section of README.md. The final import command is:

          nix run --impure .#convert-imx95-neutron-model -- \
            --accept-license \
            /path/to/${release.neutron.converter.file} \
            /path/to/neutron-converter \
            /path/to/${release.neutron.model.sourceArchive.member} \
            ${release.neutron.model.converted.sha256}
      '';
    };
    convertedModel =
      pkgs.runCommand "imx95-neutron-converted-model" {
        src = convertedModelSource;
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
        test "$(stat -c %s "$src")" = ${toString release.neutron.model.converted.size}
        test "$(sha256sum "$src" | cut -d' ' -f1)" = \
          ${lib.escapeShellArg release.neutron.model.converted.sha256}
        install -Dm0444 "$src" "$out/share/models/${release.neutron.model.converted.fileName}"
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
        neutronDeviceTreePackage = deviceTreePackage;
        neutronSmoke = smoke;
      };

      assertions = [
        {
          assertion = config.hardware.deviceTree.name == "freescale/imx95-15x15-frdm.dtb";
          message = "The Neutron role must preserve the accepted FRDM DT filename.";
        }
        {
          assertion =
            providerKind
            == "reduced-mainline"
            || providerKind == "nxp-full-combined";
          message = ''
            The Neutron role requires either its reviewed reduced provider or
            the reviewed combined NXP provider.
          '';
        }
      ];
    };
  };
}
