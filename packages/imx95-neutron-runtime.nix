{
  gitMinimal,
  lib,
  runCommand,
  runtimeRoot,
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
  members =
    [
      (runtime.members.firmware
        // {
          installedPath = "lib/firmware/NeutronFirmware.elf";
        })
      (runtime.members.driver
        // {
          installedPath = "lib/libNeutronDriver.so";
        })
    ]
    ++ map (
      header:
        header
        // {
          sourcePath = "include/${builtins.baseNameOf header.path}";
          installedPath = "include/neutron/${builtins.baseNameOf header.path}";
        }
    )
    runtime.members.headers;
  verification =
    lib.concatMapStringsSep "\n" (
      member: ''
        source_path="$src/${member.sourcePath or member.installedPath}"
        test -f "$source_path"
        test "$(stat -c %s "$source_path")" = ${toString member.size}
        test "$(git hash-object --no-filters "$source_path")" = ${member.blobSha1}
        install -Dm0444 "$source_path" "$out/${member.installedPath}"
      ''
    )
    members;
in
  runCommand "imx95-neutron-runtime-${release.neutron.versionLabels.sbom}" {
    src = runtimeRoot;
    nativeBuildInputs = [gitMinimal];

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
