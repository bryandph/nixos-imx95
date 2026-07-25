{
  lib,
  requireFile,
  runCommand,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  runtime = release.neutron.runtime;
  nxpLicense =
    lib.licenses.unfree
    // {
      fullName = "NXP Software License Agreement";
      redistributable = false;
      url = "${runtime.repository}/blob/${runtime.rev}/${runtime.license.file.path}";
    };
  mkMember = member: installedPath: let
    fileName = builtins.baseNameOf member.path;
  in
    member
    // {
      inherit fileName installedPath;
      src = requireFile {
        name = fileName;
        sha256 = member.sha256;
        message = ''
          ${fileName} is a licensed NXP Neutron runtime member and cannot be
          downloaded by this flake or redistributed through its public
          repository.

          Accept NXP's license, check out ${runtime.repository} at
          ${runtime.rev}, and run:

            nix run --impure .#import-imx95-neutron-runtime -- \
              --accept-license /path/to/neutron-${runtime.rev}

          The helper verifies the license, content register, SBOM, revision-pinned
          Git blob identities, sizes, and SHA-256 identities before adding only
          the four required runtime members to the local Nix store.
        '';
      };
    };
  members =
    [
      (mkMember runtime.members.firmware "lib/firmware/NeutronFirmware.elf")
      (mkMember runtime.members.driver "lib/libNeutronDriver.so")
    ]
    ++ map (
      header:
        mkMember header "include/neutron/${builtins.baseNameOf header.path}"
    )
    runtime.members.headers;
  verification =
    lib.concatMapStringsSep "\n" (
      member: ''
        source_path=${member.src}
        test -f "$source_path"
        test "$(stat -c %s "$source_path")" = ${toString member.size}
        test "$(sha256sum "$source_path" | cut -d' ' -f1)" = ${member.sha256}
        install -Dm0444 "$source_path" "$out/${member.installedPath}"
      ''
    )
    members;
in
  runCommand "imx95-neutron-runtime-${release.neutron.versionLabels.sbom}" {
    allowSubstitutes = false;
    preferLocalBuild = true;

    passthru = {
      inherit members;
      publicationPolicy = {
        publicChecks = false;
        publicPackages = false;
        publicReleases = false;
        redistributable = false;
      };
      releaseMapping = release;
      runtimeRevision = runtime.rev;
    };

    meta = {
      description = "Operator-imported NXP Neutron firmware, userspace driver, and headers";
      homepage = runtime.repository;
      license = nxpLicense;
      hydraPlatforms = [];
      platforms = ["aarch64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    mkdir -p "$out"
    ${verification}
  ''
