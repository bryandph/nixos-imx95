{
  lib,
  requireFile,
  runCommand,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  demo = release.licensedFirmware.m7PowerModeDemo;
  distribution = demo.distribution;
  member = demo.member;
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP Software License Agreement (LA_OPT_NXP_Software_License v63, May 2025)";
      url = "https://www.nxp.com/docs/en/disclaimer/LA_OPT_NXP_Software_License.pdf";
      redistributable = false;
    };
  src = requireFile {
    name = member.fileName;
    sha256 = member.sha256;
    message = ''
      ${member.fileName} is a licensed NXP compatibility artifact and cannot
      be downloaded or redistributed by this flake.

      Accept the applicable NXP license, obtain ${distribution.fileName}, and
      import only the pinned member:

        ./scripts/import-nxp-m7-power-mode-demo --accept-license \
          /path/to/${distribution.fileName}

      This raw binary is a U-Boot/debug compatibility oracle. Linux remoteproc
      requires ELF firmware and must not load this artifact directly.
    '';
  };
in
  runCommand "nxp-imx95-m7-power-mode-demo-${release.release.version}" {
    inherit src;

    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      inherit distribution member;
      expectedSha256 = member.sha256;
      expectedSize = member.size;
      fileName = member.fileName;
      firmwareFormat = release.m7.remoteproc.vendorDemoFormat;
      providerLicense = nxpLicense;
      release = release.release.version;
      remoteprocLoadable = false;
    };

    meta = {
      description = "Operator-supplied NXP FRDM-i.MX95 M7 power-mode compatibility firmware";
      homepage = nxpLicense.url;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    actualSize=$(stat -c %s "$src")
    if [ "$actualSize" -ne ${toString member.size} ]; then
      echo "${member.fileName} has size $actualSize; expected ${toString member.size}" >&2
      exit 1
    fi

    actualSha256=$(sha256sum "$src" | cut -d' ' -f1)
    if [ "$actualSha256" != ${lib.escapeShellArg member.sha256} ]; then
      echo "${member.fileName} failed its pinned SHA-256 check" >&2
      exit 1
    fi

    install -Dm0444 "$src" "$out/share/nxp-imx95-compatibility/${member.fileName}"
  ''
