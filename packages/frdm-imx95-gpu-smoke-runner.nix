{
  coreutils,
  gnugrep,
  gnused,
  jq,
  lib,
  libglvnd,
  mesa,
  pkg-config,
  stdenv,
  vulkan-tools,
  writeShellApplication,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  eglProbe = stdenv.mkDerivation {
    pname = "frdm-imx95-egl-render";
    version = release.release.version;
    src = ./frdm-imx95-egl-smoke.c;
    dontUnpack = true;
    nativeBuildInputs = [pkg-config];
    buildInputs = [
      libglvnd
      mesa
    ];
    buildPhase = ''
      runHook preBuild
      $CC -std=c11 -Wall -Wextra -Werror \
        $(pkg-config --cflags egl glesv2) \
        "$src" -o frdm-imx95-egl-render \
        $(pkg-config --libs egl glesv2)
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm0755 frdm-imx95-egl-render \
        "$out/bin/frdm-imx95-egl-render"
      runHook postInstall
    '';
    meta = {
      description = "Display-server-independent EGL/GLES render and readback probe";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
    };
  };
in
  writeShellApplication {
    name = "frdm-imx95-gpu-smoke";
    runtimeInputs = [
      coreutils
      eglProbe
      gnugrep
      gnused
      jq
      vulkan-tools
    ];
    text = ''
      export FRDM_IMX95_GPU_KERNEL_DRIVER=${
        lib.escapeShellArg release.multimedia.mainline.gpu.kernelDriver
      }
      export FRDM_IMX95_GPU_RENDERER=${
        lib.escapeShellArg release.multimedia.mainline.gpu.renderer
      }
      export FRDM_IMX95_GPU_VULKAN_DRIVER=${
        lib.escapeShellArg release.multimedia.mainline.gpu.vulkanDriver
      }
      export FRDM_IMX95_GPU_FIRMWARE_SOURCE=${
        lib.escapeShellArg release.multimedia.mainline.gpu.firmware.source
      }
      ${builtins.readFile ../scripts/frdm-imx95-gpu-smoke}
    '';
    passthru = {
      inherit eglProbe;
      releaseMapping = release.multimedia;
    };
    meta = {
      description = "Hardware-evidencing FRDM-i.MX95 Mali GPU smoke runner";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
    };
  }
