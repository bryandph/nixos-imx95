{
  converterSdk,
  expectedSha256 ? null,
  lib,
  modelSource,
  runCommand,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  converter = release.neutron.converter;
  model = release.neutron.model;
  outputName = "${model.name}-neutron.tflite";
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP eIQ Neutron SDK converted model output";
      redistributable = false;
      url = builtins.head converter.licenseReview.authorities;
    };
in
  runCommand "imx95-neutron-converted-model-${converter.version}" {
    nativeBuildInputs = [converterSdk];

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      inherit expectedSha256 outputName;
      modelSourceSha256 = model.sourceArchive.memberSha256;
      publicationPolicy = {
        publicChecks = false;
        publicPackages = false;
        publicReleases = false;
        redistributable = false;
      };
      releaseMapping = release;
    };

    meta = {
      description = "Deterministically converted i.MX95 Neutron smoke model";
      homepage = converter.index;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  } ''
    export HOME="$TMPDIR/home"
    export LC_ALL=C
    export TZ=UTC
    mkdir -p "$HOME"

    sourceModel=${modelSource}/${modelSource.modelPath}
    first="$TMPDIR/${model.name}-neutron-a.tflite"
    second="$TMPDIR/${model.name}-neutron-b.tflite"

    neutron_converter --version | grep -F ${lib.escapeShellArg converter.version} >/dev/null
    for output in "$first" "$second"; do
      neutron_converter \
        --input="$sourceModel" \
        --output="$output" \
        --target=${model.converted.target} \
        --force-determinism
    done

    firstHash=$(sha256sum "$first" | cut -d' ' -f1)
    secondHash=$(sha256sum "$second" | cut -d' ' -f1)
    test "$firstHash" = "$secondHash"
    ${lib.optionalString (expectedSha256 != null) ''
      test "$firstHash" = ${lib.escapeShellArg expectedSha256}
    ''}

    install -Dm0444 "$first" "$out/share/imx95-neutron/${outputName}"
    printf '%s\n' "$firstHash" >"$out/share/imx95-neutron/${outputName}.sha256"
  ''
