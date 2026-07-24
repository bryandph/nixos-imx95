{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  model = release.neutron.model;
in
  stdenvNoCC.mkDerivation {
    pname = model.name;
    version = "2018-08-02";
    src = fetchurl {
      inherit (model.sourceArchive) url sha256;
    };

    sourceRoot = ".";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      source_model=${lib.escapeShellArg model.sourceArchive.member}
      test "$(sha256sum "$source_model" | cut -d' ' -f1)" = \
        ${model.sourceArchive.memberSha256}
      install -Dm0444 "$source_model" \
        "$out/share/models/${model.sourceArchive.member}"
      runHook postInstall
    '';

    passthru = {
      inherit model;
      modelPath = "share/models/${model.sourceArchive.member}";
    };

    meta = {
      description = "Open quantized MobileNet V1 input model for Neutron conversion";
      homepage = model.sourceArchive.licenseAuthority;
      license = model.sourceArchive.license;
      platforms = lib.platforms.all;
    };
  }
