{
  autoPatchelfHook,
  cmake,
  lib,
  ninja,
  runtime,
  source,
  stdenv,
  tensorflowLite,
  tensorflowLiteSource ? tensorflowLite.src,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  delegate = release.neutron.delegate;
  aggregateLicense =
    lib.licenses.unfree
    // {
      fullName = "Apache-2.0 delegate linked with non-redistributable NXP Neutron runtime";
      redistributable = false;
      url = "${release.neutron.runtime.repository}/blob/${release.neutron.runtime.rev}/${release.neutron.runtime.license.file.path}";
    };
in
  stdenv.mkDerivation {
    pname = "tflite-neutron-delegate-imx95";
    version = delegate.version;
    src = source;

    nativeBuildInputs = [
      autoPatchelfHook
      cmake
      ninja
    ];
    buildInputs = [
      runtime
      tensorflowLite
    ];

    postPatch = ''
      cp ${./Findtensorflow-nix.cmake} cmake/modules/Findtensorflow.cmake
    '';
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DNEUTRON_INTEGRATION=ON"
      "-DNEUTRON_DRIVER_PATH=${runtime}"
      "-DNEUTRON_DRIVER_LIB=${runtime}/lib/libNeutronDriver.so"
      "-DTFLITE_SOURCE_DIR=${tensorflowLiteSource}/tensorflow/lite"
      "-DTFLITE_LIB_LOC=${tensorflowLite}/lib/libtensorflowlite.so"
      "-DTFLITE_INCLUDE_DIR=${tensorflowLite}/include"
    ];
    installPhase = ''
      runHook preInstall
      install -Dm0555 libneutron_delegate.so "$out/lib/libneutron_delegate.so"
      install -Dm0444 "$src/neutron_delegate.h" "$out/include/neutron_delegate.h"
      runHook postInstall
    '';

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      publicationPolicy = {
        publicChecks = false;
        publicPackages = false;
        publicReleases = false;
        redistributable = false;
      };
      releaseMapping = release;
      sourceRevision = delegate.rev;
      runtimeRevision = release.neutron.runtime.rev;
    };

    meta = {
      description = "TensorFlow Lite Neutron delegate linked to the licensed NXP runtime";
      homepage = delegate.repository;
      license = aggregateLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
    };
  }
