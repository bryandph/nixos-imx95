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
    name = "frdm-imx95-jpeg-smoke";
    runtimeInputs = [
      coreutils
      gnugrep
      jq
      v4l-utils
    ];
    text = ''
      export FRDM_IMX95_JPEG_DRIVER=${
        lib.escapeShellArg release.multimedia.mainline.jpeg.driver
      }
      ${builtins.readFile ../scripts/frdm-imx95-jpeg-smoke}
    '';
    passthru.releaseMapping = release.multimedia;
    meta = {
      description = "Generated V4L2 JPEG encode/decode smoke runner for FRDM-i.MX95";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
    };
  }
