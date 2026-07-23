{
  fetchFromGitHub,
  lib,
  stdenv,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  component = release.sources.imxMkimage;
in
  stdenv.mkDerivation {
    inherit (component) pname version;

    src = fetchFromGitHub component.fetchFromGitHub;
    strictDeps = true;
    dontConfigure = true;

    postPatch = ''
      printf '#define MKIMAGE_COMMIT 0x%s\n' \
        '${builtins.substring 0 8 component.fetchFromGitHub.rev}' \
        > src/build_info.h
    '';

    makeFlags = ["bin"];
    env.CFLAGS = "-O2 -Wall -std=c99";

    installPhase = ''
      runHook preInstall

      install -Dm0755 mkimage_imx8 "$out/bin/mkimage_imx8"
      mkdir -p "$out/share/imx-mkimage"
      cp -R . "$out/share/imx-mkimage"

      runHook postInstall
    '';

    passthru = {
      inherit release;
      assemblyRoot = "share/imx-mkimage";
      provenance = {
        inherit (component) branch licenseFile;
        inherit (component.fetchFromGitHub) owner repo rev sha256;
      };
    };

    meta = {
      description = "NXP imx-mkimage tooling and i.MX95 assembly sources";
      homepage = "https://github.com/nxp-imx/imx-mkimage";
      license = component.license;
      platforms = lib.platforms.linux;
      sourceProvenance = [lib.sourceTypes.fromSource];
    };
  }
