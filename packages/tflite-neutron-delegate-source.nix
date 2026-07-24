{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  source = release.neutron.delegate;
in
  stdenvNoCC.mkDerivation {
    pname = "tflite-neutron-delegate-source";
    version = source.version;
    src = fetchFromGitHub source.fetchFromGitHub;

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      cp -R . "$out"
      runHook postInstall
    '';

    passthru = {
      releaseMapping = release;
      sourceRevision = source.rev;
    };

    meta = {
      description = "Release-pinned TensorFlow Lite Neutron delegate source";
      homepage = source.repository;
      license = source.license;
      platforms = lib.platforms.linux;
    };
  }
