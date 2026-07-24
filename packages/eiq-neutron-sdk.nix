{
  autoPatchelfHook,
  lib,
  python311Packages,
  stdenv,
  wheel,
  zlib,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  converter = release.neutron.converter;
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP eIQ Neutron SDK Software License";
      redistributable = false;
      url = builtins.head converter.licenseReview.authorities;
    };
in
  python311Packages.buildPythonPackage {
    pname = "eiq-neutron-sdk";
    inherit (converter) version;
    format = "wheel";
    src = wheel;

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [
      stdenv.cc.cc.lib
      zlib
    ];

    preUnpack = ''
      test "$(sha256sum "$src" | cut -d' ' -f1)" = ${converter.sha256}
    '';
    postInstall = ''
      ln -s neutron_converter "$out/bin/neutron-converter"
    '';

    doCheck = false;
    pythonImportsCheck = ["eiq_neutron_sdk"];

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
      wheelSha256 = converter.sha256;
    };

    meta = {
      description = "Operator-supplied NXP eIQ Neutron SDK converter";
      homepage = converter.index;
      license = nxpLicense;
      hydraPlatforms = [];
      mainProgram = "neutron_converter";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
