{
  fetchFromGitHub,
  gcc-arm-embedded,
  lib,
  stdenvNoCC,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  component = release.sources.oei;
  armToolchain = gcc-arm-embedded;
  crossPrefix = release.toolchains.armBareMetal.targetPrefix;
  outputName = "oei-${release.machine.oeiCore}-${release.machine.oeiConfig}.bin";
in
  stdenvNoCC.mkDerivation {
    inherit (component) pname version;

    src = fetchFromGitHub component.fetchFromGitHub;
    strictDeps = true;
    nativeBuildInputs = [armToolchain];
    hardeningDisable = ["all"];
    dontConfigure = true;
    enableParallelBuilding = true;

    postPatch = ''
      substituteInPlace oei/makefiles/build_info.mak \
        --replace-fail /bin/echo echo
    '';

    buildPhase = ''
      runHook preBuild

      make \
        board=${release.machine.oeiBoard} \
        oei=${release.machine.oeiConfig} \
        r=${release.machine.socRevision} \
        DDR_CONFIG=${release.machine.oeiDdrConfig} \
        DEBUG=1 \
        OEI_CROSS_COMPILE=${crossPrefix} \
        clean
      make -j"$NIX_BUILD_CORES" \
        board=${release.machine.oeiBoard} \
        oei=${release.machine.oeiConfig} \
        r=${release.machine.socRevision} \
        DDR_CONFIG=${release.machine.oeiDdrConfig} \
        DEBUG=1 \
        OEI_CROSS_COMPILE=${crossPrefix}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm0444 \
        build/${release.machine.oeiBoard}/${release.machine.oeiConfig}/${outputName} \
        "$out/${outputName}"

      runHook postInstall
    '';

    passthru = {
      inherit release;
      artifacts.oei = outputName;
      provenance = {
        inherit (component) branch licenseFile;
        inherit (component.fetchFromGitHub) owner repo rev sha256;
      };
    };

    meta = {
      description = "NXP OEI DDR initialization firmware built from source for the FRDM-i.MX95";
      homepage = "https://github.com/nxp-imx/imx-oei";
      license = component.license;
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.fromSource];
    };
  }
