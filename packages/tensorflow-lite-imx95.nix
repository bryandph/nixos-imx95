{
  buildBazelPackage,
  buildPackages,
  callPackage,
  fetchFromGitHub,
  lib,
  stdenv,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  source = release.neutron.tensorflowLite;
  bazel650 = callPackage ./bazel-6.5.0.nix {};
  pythonEnv = buildPackages.python312.withPackages (
    ps:
      with ps; [
        distutils
        numpy
      ]
  );
in
  buildBazelPackage {
    name = "tensorflow-lite-imx95";
    version = source.version;

    src = fetchFromGitHub source.fetchFromGitHub;
    bazel = bazel650;

    nativeBuildInputs = [
      pythonEnv
      buildPackages.perl
    ];

    bazelTargets = [
      "//tensorflow/lite:libtensorflowlite.so"
      "//tensorflow/lite/c:tensorflowlite_c"
      "//tensorflow/lite/tools/benchmark:benchmark_model"
    ];
    bazelFlags =
      [
        "--config=opt"
        "--enable_bzlmod=false"
      ]
      ++ lib.optionals (stdenv.hostPlatform.system != stdenv.buildPlatform.system) [
        "--config=elinux_aarch64"
      ];
    bazelBuildFlags = [
      "--cxxopt=--std=c++17"
      "--copt=-Wno-error=incompatible-pointer-types"
    ];

    buildAttrs = {
      preBuild = ''
        patchShebangs "$bazelOut/external"
        substituteInPlace "$bazelOut/external/XNNPACK/BUILD.bazel" \
          --replace-fail '$(location generate_build_identifier_py)' '${pythonEnv.interpreter} $(location scripts/generate-build-identifier.py)' \
          --replace-fail 'tools = [":generate_build_identifier_py"]' 'tools = ["scripts/generate-build-identifier.py"]'
      '';
      installPhase = ''
        mkdir -p "$out"/{bin,lib}
        cp bazel-bin/tensorflow/lite/c/libtensorflowlite_c.so "$out/lib/"
        cp bazel-bin/tensorflow/lite/libtensorflowlite.so "$out/lib/"
        cp bazel-bin/tensorflow/lite/tools/benchmark/benchmark_model "$out/bin/"

        find tensorflow -type f -name '*.h' | while read -r header; do
          install -Dm0444 "$header" "$out/include/$header"
        done
        (
          cd "$bazelOut/external/com_google_absl"
          find absl -type f -name '*.h' | while read -r header; do
            install -Dm0444 "$header" "$out/include/$header"
          done
        )
        (
          cd "$bazelOut/external/gemmlowp"
          find . -type f -name '*.h' | while read -r header; do
            install -Dm0444 "$header" "$out/include/''${header#./}"
          done
        )
        cp -R "$bazelOut/external/eigen_archive/Eigen" "$out/include/"
        cp -R "$bazelOut/external/eigen_archive/unsupported" "$out/include/"
        cp -R "$bazelOut/external/ruy/ruy" "$out/include/"
        cp -R "$bazelOut/external/flatbuffers/include/." "$out/include/"
        cp -R "$bazelOut/external/cpuinfo/include/." "$out/include/"
        cp -R "$bazelOut/external/pthreadpool/include/." "$out/include/"
        cp -R "$bazelOut/external/FP16/include/." "$out/include/"
        cp -R "$bazelOut/external/FXdiv/include/." "$out/include/"

        "$CXX" \
          -std=c++17 \
          -O2 \
          -I"$out/include" \
          ${./imx95-neutron-benchmark.cc} \
          -L"$out/lib" \
          -Wl,-rpath,"$out/lib" \
          -ltensorflowlite \
          -ldl \
          -pthread \
          -o "$out/bin/benchmark_model_dynamic"
      '';
    };

    fetchAttrs.sha256 = "sha256-tevt5vM9I21t7OeuXMasPl+AeolPTzA3WmIOz39S4C8=";

    env = {
      PYTHON_BIN_PATH = pythonEnv.interpreter;
      HERMETIC_PYTHON_VERSION = "3.12";
      TF_NEED_CLANG = "0";
      TF_NEED_CUDA = "0";
      TF_NEED_ROCM = "0";
      TF_NEED_TENSORRT = "0";
    };
    dontAddBazelOpts = true;
    removeRulesCC = false;
    postPatch = ''
      rm -f .bazelversion
      touch third_party/xla/third_party/tsl/WORKSPACE
    '';
    preConfigure = ''
      patchShebangs configure
    '';
    dontAddPrefix = true;
    configurePlatforms = [];

    passthru = {
      releaseMapping = release;
      sourceRevision = source.rev;
    };

    meta = {
      description = "Release-pinned TensorFlow Lite runtime and benchmark for i.MX95";
      homepage = source.repository;
      license = source.license;
      platforms = ["aarch64-linux"];
    };
  }
