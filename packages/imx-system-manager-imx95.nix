{
  fetchFromGitHub,
  gcc-arm-embedded,
  lib,
  perl,
  stdenvNoCC,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  component = release.sources.systemManager;
  armToolchain = gcc-arm-embedded;
  crossPrefix = release.toolchains.armBareMetal.targetPrefix;
in
  stdenvNoCC.mkDerivation {
    inherit (component) pname version;

    src = fetchFromGitHub component.fetchFromGitHub;
    strictDeps = true;
    nativeBuildInputs = [
      armToolchain
      perl
    ];
    hardeningDisable = ["all"];
    dontConfigure = true;
    enableParallelBuilding = true;

    postPatch = ''
      substituteInPlace sm/makefiles/build_info.mak \
        --replace-fail /bin/echo echo
      patchShebangs configs/configtool.pl
    '';

    buildPhase = ''
      runHook preBuild

      make \
        CONFIG=${release.machine.systemManagerConfig} \
        M=${release.machine.systemManagerMonitorMode} \
        SM_CROSS_COMPILE=${crossPrefix} \
        clean
      make \
        CONFIG=${release.machine.systemManagerConfig} \
        M=${release.machine.systemManagerMonitorMode} \
        SM_CROSS_COMPILE=${crossPrefix} \
        cfg
      make -j"$NIX_BUILD_CORES" \
        CONFIG=${release.machine.systemManagerConfig} \
        M=${release.machine.systemManagerMonitorMode} \
        SM_CROSS_COMPILE=${crossPrefix}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm0444 \
        build/${release.machine.systemManagerConfig}/${release.machine.systemManagerImage} \
        "$out/${release.machine.systemManagerImage}"

      runHook postInstall
    '';

    passthru = {
      inherit release;
      artifacts.systemManager = release.machine.systemManagerImage;
      provenance = {
        inherit (component) branch licenseFile;
        inherit (component.fetchFromGitHub) owner repo rev sha256;
      };
    };

    meta = {
      description = "NXP System Manager firmware built from source for i.MX95";
      homepage = "https://github.com/nxp-imx/imx-sm";
      license = component.license;
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.fromSource];
    };
  }
