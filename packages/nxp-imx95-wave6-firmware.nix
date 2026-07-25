{
  coreutils,
  gnutar,
  gzip,
  lib,
  requireFile,
  runCommand,
  xz,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  firmware = release.multimedia.wave6.firmware;
  distribution = release.licensedFirmware.ddr.distribution;
  downloadUrl = "https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/${distribution.fileName}";
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = firmware.license.fullName;
      url = downloadUrl;
      redistributable = false;
    };
  src = requireFile {
    name = distribution.fileName;
    sha256 = distribution.sha256;
    message = ''
      ${distribution.fileName} is licensed NXP firmware and cannot be fetched
      or redistributed by this flake.

      Accept NXP's license, download the release-pinned distribution, and run:

        ./scripts/import-nxp-wave6-firmware --accept-license \
          /path/to/${distribution.fileName}

      The package extracts only ${firmware.member.fileName} into its output.
    '';
  };
in
  runCommand "nxp-imx95-wave6-firmware-${release.release.version}" {
    inherit src;
    nativeBuildInputs = [
      coreutils
      gnutar
      gzip
      xz
    ];
    allowSubstitutes = false;
    preferLocalBuild = true;
    passthru = {
      inherit distribution;
      selectedMember = firmware.member;
      publicationPolicy = firmware.publicationPolicy;
      releaseMapping = release.multimedia;
    };
    meta = {
      description = "Operator-supplied i.MX95 Wave6 codec firmware";
      homepage = downloadUrl;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    work_dir=$(mktemp -d)
    trap 'rm -rf -- "$work_dir"' EXIT

    cd "$work_dir"
    sh "$src" --auto-accept --force
    member="$work_dir/${firmware.member.archivePath}"
    test -f "$member"

    install -Dm0444 "$member" \
      "$out/lib/firmware/${firmware.member.installPath}"
    test "$(find "$out" -type f | wc -l)" -eq 1
    if grep -R -a -F -l "$src" "$out"; then
      echo "Wave6 firmware output unexpectedly retained its source distribution" >&2
      exit 1
    fi
  ''
