{
  lib,
  requireFile,
  runCommand,
}: let
  pname = "nxp-imx95-boot-container";
  version = "6.18.2-1.0.0";
  fileName = "imx-boot-imx95-15x15-lpddr4x-frdm-sd.bin-flash_all";
  expectedSize = 2829312;
  expectedHash = "sha256-/fs06wgKQFft5nRABkRwam9zw2NcDFEFEKfDvfpz/eY=";
  sourceArchiveName = "LF_v6.18.2-1.0.0_images_IMX95.zip";
  sourceArchiveHash = "sha256-KkVqJz/o6WeNj9fgy/O1L2x67/U/QAF9c1CV2rKbuwc=";
  downloadPage = "https://www.nxp.com/webapp/Download?colCode=L6.18.2-1.0.0_MX95&appType=license";

  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
      url = downloadPage;
      redistributable = false;
    };

  src = requireFile {
    name = fileName;
    hash = expectedHash;
    message = ''
      The FRDM-i.MX95 SD image requires NXP's licensed boot container.
      It cannot be downloaded or redistributed by this flake.

      1. Accept NXP's license and download ${sourceArchiveName} from:
         ${downloadPage}
      2. From the nixos-imx95 checkout, run:
         ./scripts/import-nxp-boot-container /path/to/${sourceArchiveName}
      3. Re-run the build with this unfree package explicitly permitted.

      The helper verifies both the source archive and extracted member before
      adding only ${fileName} to the local Nix store.
    '';
  };
in
  runCommand "${pname}-${version}" {
    inherit src;

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      inherit
        downloadPage
        expectedHash
        expectedSize
        fileName
        sourceArchiveHash
        sourceArchiveName
        ;
      bootContainerOffsetKiB = 32;
      reservedBootRegionMiB = 8;
    };

    meta = {
      description = "Licensed NXP AHAB boot container for the FRDM-i.MX95";
      homepage = downloadPage;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
      sourceProvenance = with lib.sourceTypes; [
        binaryFirmware
        binaryNativeCode
      ];
    };
  } ''
    actualSize=$(stat -c %s "$src")
    if [ "$actualSize" -ne ${toString expectedSize} ]; then
      echo "NXP boot container has size $actualSize; expected ${toString expectedSize}" >&2
      exit 1
    fi

    install -Dm0444 "$src" "$out/${fileName}"
  ''
