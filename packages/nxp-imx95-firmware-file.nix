{
  distribution,
  downloadUrl,
  fileName,
  lib,
  pname,
  requireFile,
  runCommand,
  sha256,
  size,
  version,
}: let
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
      url = downloadUrl;
      redistributable = false;
    };

  src = requireFile {
    name = fileName;
    inherit sha256;
    message = ''
      ${fileName} is licensed NXP firmware and cannot be downloaded by this
      flake or redistributed through its public repository.

      Accept NXP's license, download ${distribution.fileName}, and run:

        ./scripts/import-nxp-firmware --accept-license \
          /path/to/firmware-ele-imx-2.0.6-c0b284c.bin \
          /path/to/firmware-imx-8.32-1991416.bin

      The helper verifies both distributions and adds only the five required
      i.MX95 firmware members to the local Nix store.
    '';
  };
in
  runCommand "${pname}-${version}" {
    inherit src;

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      inherit
        distribution
        downloadUrl
        fileName
        sha256
        size
        ;
      expectedSha256 = sha256;
      expectedSize = size;
      providerLicense = nxpLicense;
      release = version;
    };

    meta = {
      description = "Operator-supplied licensed NXP firmware: ${fileName}";
      homepage = downloadUrl;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    actualSize=$(stat -c %s "$src")
    if [ "$actualSize" -ne ${toString size} ]; then
      echo "${fileName} has size $actualSize; expected ${toString size}" >&2
      exit 1
    fi

    actualSha256=$(sha256sum "$src" | cut -d' ' -f1)
    if [ "$actualSha256" != ${lib.escapeShellArg sha256} ]; then
      echo "${fileName} failed its pinned SHA-256 check" >&2
      exit 1
    fi

    install -Dm0444 "$src" "$out/${fileName}"
  ''
