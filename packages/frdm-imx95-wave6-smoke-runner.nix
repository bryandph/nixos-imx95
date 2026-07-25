{
  coreutils,
  gnugrep,
  jq,
  lib,
  v4l-utils,
  writeShellApplication,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
in
  writeShellApplication {
    name = "frdm-imx95-wave6-smoke";
    runtimeInputs = [
      coreutils
      gnugrep
      jq
      v4l-utils
    ];
    text = ''
      export FRDM_IMX95_WAVE6_DRIVER=${
        lib.escapeShellArg release.multimedia.wave6.userspace.expectedDriver
      }
      export FRDM_IMX95_WAVE6_WIDTH=${
        toString release.multimedia.wave6.userspace.smokeFrame.width
      }
      export FRDM_IMX95_WAVE6_HEIGHT=${
        toString release.multimedia.wave6.userspace.smokeFrame.height
      }
      export FRDM_IMX95_WAVE6_FRAME_BYTES=${
        toString release.multimedia.wave6.userspace.smokeFrame.bytes
      }
      ${builtins.readFile ../scripts/frdm-imx95-wave6-smoke}
    '';
    passthru.releaseMapping = release.multimedia;
    meta = {
      description = "Open V4L2 H.264/H.265 Wave6 hardware smoke runner";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
    };
  }
