{lib, ...}: let
  release = import ../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  converterWheelPath = builtins.getEnv "NIXOS_IMX95_NEUTRON_CONVERTER_WHEEL";
  converterWheelConfigured = converterWheelPath != "";
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    importer = pkgs.callPackage ../packages/import-imx95-neutron-runtime.nix {};
    modelSource = pkgs.callPackage ../packages/imx95-neutron-model-source.nix {};
    converterWheel = builtins.path {
      path = converterWheelPath;
      name = release.neutron.converter.file;
    };
    converterSdk = pkgs.callPackage ../packages/eiq-neutron-sdk.nix {
      wheel = converterWheel;
    };
    convertedModel = pkgs.callPackage ../packages/imx95-neutron-converted-model.nix {
      inherit converterSdk modelSource;
      expectedSha256 = release.neutron.model.converted.sha256;
    };
    smokeRunner = pkgs.callPackage ../packages/frdm-imx95-neutron-smoke-runner.nix {};
    tensorflowLite = pkgs.callPackage ../packages/tensorflow-lite-imx95.nix {};
    delegateSource = pkgs.callPackage ../packages/tflite-neutron-delegate-source.nix {};
    policyRuntime = pkgs.callPackage ../packages/imx95-neutron-runtime.nix {};
    policyAggregate = pkgs.callPackage ../packages/tflite-neutron-delegate-imx95.nix {
      runtime = policyRuntime;
      source = delegateSource;
      inherit tensorflowLite;
    };
    policyJson = pkgs.writeText "imx95-neutron-publication-policy.json" (
      builtins.toJSON {
        runtime = {
          allowSubstitutes = policyRuntime.allowSubstitutes;
          hydraPlatforms = policyRuntime.meta.hydraPlatforms;
          preferLocalBuild = policyRuntime.preferLocalBuild;
          publication = policyRuntime.publicationPolicy;
          redistributable = policyRuntime.meta.license.redistributable;
        };
        aggregate = {
          allowSubstitutes = policyAggregate.allowSubstitutes;
          hydraPlatforms = policyAggregate.meta.hydraPlatforms;
          preferLocalBuild = policyAggregate.preferLocalBuild;
          publication = policyAggregate.publicationPolicy;
          redistributable = policyAggregate.meta.license.redistributable;
        };
      }
    );
  in {
    packages =
      {
        import-imx95-neutron-runtime = importer;
        imx95-neutron-model-source = modelSource;
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        convert-imx95-neutron-model =
          pkgs.callPackage ../packages/convert-imx95-neutron-model.nix {};
      }
      // lib.optionalAttrs (system == "x86_64-linux" && converterWheelConfigured) {
        eiq-neutron-sdk = converterSdk;
        imx95-neutron-converted-model = convertedModel;
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        frdm-imx95-neutron-smoke-runner = smokeRunner;
        tensorflow-lite-imx95 = tensorflowLite;
        tflite-neutron-delegate-source = delegateSource;
      };

    checks =
      {
        neutron-runtime-import-guard = pkgs.runCommand "frdm-imx95-neutron-runtime-import-guard" {} ''
          if ${lib.getExe importer}; then
            echo "Neutron runtime importer accepted a missing license acknowledgement" >&2
            exit 1
          fi
          touch "$out"
        '';
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        neutron-publication-policy =
          pkgs.runCommand "frdm-imx95-neutron-publication-policy" {
            nativeBuildInputs = [pkgs.jq];
          } ''
            jq -e '
              all(.runtime, .aggregate;
                .allowSubstitutes == false and
                .preferLocalBuild == true and
                .redistributable == false and
                .hydraPlatforms == [] and
                .publication.publicChecks == false and
                .publication.publicPackages == false and
                .publication.publicReleases == false and
                .publication.redistributable == false)
            ' ${policyJson} >/dev/null
            cp ${policyJson} "$out"
          '';
        neutron-smoke-fixtures = let
          fakeBenchmark = pkgs.writeShellScriptBin "benchmark_model" ''
            output=
            profile=
            graph=
            delegate=
            for argument in "$@"; do
              case "$argument" in
                --graph=*) graph="''${argument#*=}" ;;
                --external_delegate_path=*) delegate="''${argument#*=}" ;;
                --output_filepath=*) output="''${argument#*=}" ;;
                --op_profiling_output_file=*) profile="''${argument#*=}" ;;
              esac
            done
            test -f "$graph"
            if grep -q bad-model "$graph"; then
              exit 1
            fi
            printf '\001\002' >"$output"
            if test -n "$delegate"; then
              printf '1 nodes delegated out of 1 nodes with 1 partitions.\n'
              printf 'node,type,time\n0,Delegate,1\n' >"$profile"
              printf '0x0 0x1 0x0 0x0 0x0 0x0 0x0 0x0 0x1\n' \
                >"$NEUTRON_PERF_COUNTERS"
            fi
          '';
        in
          pkgs.runCommand "frdm-imx95-neutron-smoke-fixtures" {
            nativeBuildInputs = [pkgs.jq];
          } ''
            mkdir -p fixture
            printf good-model > fixture/cpu.tflite
            printf good-model > fixture/neutron.tflite
            printf bad-model > fixture/bad.tflite
            printf delegate > fixture/libneutron_delegate.so
            printf firmware > fixture/NeutronFirmware.elf
            printf device > fixture/neutron0
            printf '0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0\n' \
              > fixture/perf_counters

            export NEUTRON_BENCHMARK=${lib.getExe fakeBenchmark}
            export NEUTRON_CPU_MODEL=$PWD/fixture/cpu.tflite
            export NEUTRON_REPORT=$PWD/cpu.json
            ${lib.getExe smokeRunner} --cpu-only
            jq -e '.accelerated == false and .acceptance == false' cpu.json >/dev/null

            export NEUTRON_DELEGATE=$PWD/fixture/libneutron_delegate.so
            export NEUTRON_MODEL=$PWD/fixture/neutron.tflite
            export NEUTRON_DEVICE=$PWD/fixture/neutron0
            export NEUTRON_FIRMWARE=$PWD/fixture/NeutronFirmware.elf
            export NEUTRON_PERF_COUNTERS=$PWD/fixture/perf_counters
            export NEUTRON_REPORT=$PWD/neutron.json
            ${lib.getExe smokeRunner}
            jq -e \
              '.accelerated == true and .acceptance == true and
               .delegatedNodes == 1 and
               .independentActivity == "debugfs-perf-counters-moved"' \
              neutron.json >/dev/null

            expect_failure() {
              if ${lib.getExe smokeRunner}; then
                echo "$1 negative control unexpectedly passed" >&2
                exit 1
              fi
            }

            saved=$NEUTRON_DELEGATE
            export NEUTRON_DELEGATE=$PWD/fixture/missing-delegate.so
            expect_failure missing-delegate
            export NEUTRON_DELEGATE=$saved

            saved=$NEUTRON_DEVICE
            export NEUTRON_DEVICE=$PWD/fixture/missing-device
            expect_failure missing-device
            export NEUTRON_DEVICE=$saved

            saved=$NEUTRON_FIRMWARE
            export NEUTRON_FIRMWARE=$PWD/fixture/missing-firmware
            expect_failure missing-firmware
            export NEUTRON_FIRMWARE=$saved

            chmod 000 "$NEUTRON_DEVICE"
            expect_failure bad-permission
            chmod 600 "$NEUTRON_DEVICE"

            export NEUTRON_MODEL=$PWD/fixture/bad.tflite
            expect_failure bad-model

            cp neutron.json "$out"
          '';
      };
  };
}
