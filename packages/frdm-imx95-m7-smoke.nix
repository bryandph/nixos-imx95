{
  fetchurl,
  gnutar,
  gzip,
  lib,
  runCommand,
  rustPlatform,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  bsp = {
    repository = "https://git.bph/bryan/frdm-imx95-bsp";
    rev = "2ecc166a18c4a00853a5a316bbcba6d91147bc85";
    archiveHash = "sha256-fl+KSl4YpCxDl4W0hZ6v6NXSaDrBL7dRO7nQfggf1wI=";
    license = "MIT OR Apache-2.0";
  };
  bspArchive = fetchurl {
    url = "${bsp.repository}/archive/${bsp.rev}.tar.gz";
    hash = bsp.archiveHash;
    # git.bph uses the operator CA. The fixed hash authenticates the archive
    # content even on public builders that do not carry that CA certificate.
    curlOptsList = ["--insecure"];
  };
  bspSource =
    runCommand "frdm-imx95-bsp-${builtins.substring 0 7 bsp.rev}" {
      nativeBuildInputs = [
        gnutar
        gzip
      ];
    } ''
      mkdir "$out"
      tar -xzf ${bspArchive} --strip-components=1 -C "$out"
    '';
  source = runCommand "frdm-imx95-m7-smoke-source" {} ''
    cp -R ${lib.cleanSource ../firmware/frdm-imx95-m7-smoke} "$out"
    chmod -R u+w "$out"
    substituteInPlace "$out/Cargo.toml" \
      --replace-fail \
      'bsp-frdm-imx95 = { git = "https://git.bph/bryan/frdm-imx95-bsp.git", rev = "${bsp.rev}" }' \
      'bsp-frdm-imx95 = { path = "${bspSource}" }'
    cp ${../firmware/frdm-imx95-m7-smoke/Cargo.nix.lock} "$out/Cargo.lock"
  '';
  provenance = {
    inherit bsp;
    firmware = {
      name = "frdm-imx95-m7-smoke";
      version = "0.1.0";
      license = "MIT";
    };
    release = release.release.version;
    rust = {
      target = "thumbv7em-none-eabihf";
      toolchain = "1.85.1";
    };
  };
in
  rustPlatform.buildRustPackage {
    pname = "frdm-imx95-m7-smoke";
    version = "0.1.0";

    src = source;

    cargoLock = {
      lockFile = ../firmware/frdm-imx95-m7-smoke/Cargo.nix.lock;
    };

    buildType = "release";
    auditable = false;
    doCheck = false;
    dontStrip = true;

    buildPhase = ''
      runHook preBuild
      cargo build \
        -j "$NIX_BUILD_CORES" \
        --offline \
        --profile release \
        --locked \
        --target thumbv7em-none-eabihf
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm0444 \
        target/thumbv7em-none-eabihf/release/frdm-imx95-m7-smoke \
        "$out/lib/firmware/frdm-imx95/frdm-imx95-m7-smoke.elf"
      install -Dm0444 /dev/stdin \
        "$out/share/frdm-imx95-m7-smoke/provenance.json" \
        <<'EOF'
      ${builtins.toJSON provenance}
      EOF

      runHook postInstall
    '';

    passthru = {
      inherit provenance;
      firmwarePath = "lib/firmware/frdm-imx95/frdm-imx95-m7-smoke.elf";
      licensedNxpArtifacts = [];
    };

    meta = {
      description = "Harmless Embassy UART/timer smoke firmware for the FRDM-i.MX95 M7";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  }
