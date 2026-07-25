{
  config,
  inputs,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") (
      let
        release = import ../packages/imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
        gpuSmoke = pkgs.callPackage ../packages/frdm-imx95-gpu-smoke-runner.nix {};
        jpegSmoke = pkgs.callPackage ../packages/frdm-imx95-jpeg-smoke-runner.nix {};
        wave6Smoke = pkgs.callPackage ../packages/frdm-imx95-wave6-smoke-runner.nix {};
        wave6Kernel = pkgs.callPackage ../packages/linux-imx95-wave6.nix {};
        wave6Firmware = pkgs.callPackage ../packages/nxp-imx95-wave6-firmware.nix {};
        mkEvaluation = modules:
          inputs.nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules =
              modules
              ++ [
                {
                  fileSystems."/".device = "/dev/disk/by-label/NIXOS_SD";
                  fileSystems."/".fsType = "ext4";
                  nixpkgs.config.allowUnfreePredicate = package:
                    builtins.elem (lib.getName package) [
                      "nxp-imx95-wave6-firmware"
                    ];
                  system.stateVersion = "26.05";
                }
              ];
          };
        baseline = mkEvaluation [
          config.flake.modules.nixos.frdm-imx95-core
        ];
        multimedia = mkEvaluation [
          config.flake.modules.nixos.frdm-imx95-core
          config.flake.modules.nixos.frdm-imx95-multimedia
        ];
        wave6 = mkEvaluation [
          config.flake.modules.nixos.frdm-imx95-core
          config.flake.modules.nixos.frdm-imx95-wave6-vpu
        ];
      in {
        packages = {
          frdm-imx95-gpu-smoke = gpuSmoke;
          frdm-imx95-jpeg-smoke = jpegSmoke;
          frdm-imx95-wave6-smoke = wave6Smoke;
          linux-imx95-wave6 = wave6Kernel;
        };

        checks = {
          multimedia-module-policy =
            pkgs.runCommand "frdm-imx95-multimedia-module-policy" {
              exportReferencesGraph = [
                "baseline-system-closure"
                baseline.config.system.build.toplevel
              ];
            } ''
              test ${
                if multimedia.config.hardware.graphics.enable
                then "1"
                else "0"
              } = 1
              test ${
                if
                  multimedia.config.boot.kernelPackages.kernel.outPath
                  == baseline.config.boot.kernelPackages.kernel.outPath
                then "1"
                else "0"
              } = 1
              test ${
                if
                  builtins.hasAttr "wave6"
                  baseline.options.hardware.nxp.imx95 or {}
                then "0"
                else "1"
              } = 1
              test ${
                if
                  builtins.elem gpuSmoke
                  multimedia.config.environment.systemPackages
                then "1"
                else "0"
              } = 1
              test ${
                if
                  builtins.elem jpegSmoke
                  multimedia.config.environment.systemPackages
                then "1"
                else "0"
              } = 1
              if grep -Eqi 'wave6|gpu-smoke|jpeg-smoke' \
                baseline-system-closure; then
                echo "baseline system unexpectedly references multimedia content" >&2
                exit 1
              fi
              touch "$out"
            '';

          multimedia-release-alignment = pkgs.runCommand "frdm-imx95-multimedia-release-alignment" {} ''
            test ${lib.escapeShellArg gpuSmoke.releaseMapping.release} = \
              ${lib.escapeShellArg release.multimedia.release}
            test ${lib.escapeShellArg jpegSmoke.releaseMapping.release} = \
              ${lib.escapeShellArg release.multimedia.release}
            test ${lib.escapeShellArg wave6Smoke.releaseMapping.release} = \
              ${lib.escapeShellArg release.multimedia.release}
            test ${lib.escapeShellArg wave6Kernel.providerKind} = \
              ${lib.escapeShellArg release.multimedia.wave6.kernelDelta.providerSelection.selected}
            test ${
              toString (
                release.multimedia.wave6.userspace.smokeFrame.width
                * release.multimedia.wave6.userspace.smokeFrame.height
                * 3
                / 2
              )
            } -eq ${toString release.multimedia.wave6.userspace.smokeFrame.bytes}
            touch "$out"
          '';

          wave6-module-policy = pkgs.runCommand "frdm-imx95-wave6-module-policy" {} ''
            test ${lib.escapeShellArg wave6.config.hardware.nxp.imx95.wave6.providerKind} = \
              full-nxp-reference
            test ${lib.escapeShellArg wave6.config.hardware.nxp.imx95.wave6.firmwareMember} = \
              wave633c_codec_fw.bin
            test ${
              if wave6Firmware.allowSubstitutes
              then "0"
              else "1"
            } = 1
            test ${
              if wave6Firmware.preferLocalBuild
              then "1"
              else "0"
            } = 1
            test ${
              if wave6Firmware.meta.license.redistributable
              then "0"
              else "1"
            } = 1
            test ${toString (builtins.length wave6Firmware.meta.hydraPlatforms)} -eq 0
            test ${toString (builtins.length wave6Firmware.selectedMember.installPaths)} -eq 1
            test ${
              if wave6Firmware.releaseMapping.wave6.firmware.localImport.runtimeClosureContainsDistribution
              then "0"
              else "1"
            } = 1
            touch "$out"
          '';
        };
      }
    );
}
