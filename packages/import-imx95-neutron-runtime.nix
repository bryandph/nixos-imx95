{
  coreutils,
  gitMinimal,
  lib,
  nix,
  writeShellApplication,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  runtime = release.neutron.runtime;
  records =
    [
      (runtime.license.file // {destination = "-";})
      (runtime.license.contentRegister // {destination = "-";})
      (runtime.sbom // {destination = "-";})
      (runtime.members.firmware
        // {
          destination = "lib/firmware/NeutronFirmware.elf";
        })
      (runtime.members.driver
        // {
          destination = "lib/libNeutronDriver.so";
        })
    ]
    ++ map (
      header:
        header
        // {
          destination = "include/${builtins.baseNameOf header.path}";
        }
    )
    runtime.members.headers;
  recordLines =
    lib.concatMapStringsSep "\n" (
      record: "    ${lib.escapeShellArg "${record.path}|${record.blobSha1}|${toString record.size}|${record.destination}"}"
    )
    records;
in
  writeShellApplication {
    name = "import-imx95-neutron-runtime";
    runtimeInputs = [
      coreutils
      gitMinimal
      nix
    ];
    text = ''
            usage() {
              echo "usage: $0 --accept-license /path/to/neutron-${runtime.rev}" >&2
            }

            if [[ $# -ne 2 || "$1" != "--accept-license" ]]; then
              usage
              exit 2
            fi

            source_root=$(realpath "$2")
            if [[ ! -d "$source_root" ]]; then
              echo "Neutron source directory not found: $source_root" >&2
              exit 1
            fi

            records=(
      ${recordLines}
            )

            work_dir=$(mktemp -d "''${TMPDIR:-/tmp}/imx95-neutron-runtime.XXXXXX")
            trap 'rm -rf -- "$work_dir"' EXIT
            import_root="$work_dir/imx95-neutron-runtime-${release.neutron.versionLabels.sbom}"

            for record in "''${records[@]}"; do
              IFS='|' read -r relative_path expected_blob expected_size destination <<<"$record"
              source_path="$source_root/$relative_path"

              if [[ ! -f "$source_path" ]]; then
                echo "Required Neutron member not found: $relative_path" >&2
                exit 1
              fi

              actual_size=$(stat -c %s "$source_path")
              if [[ "$actual_size" != "$expected_size" ]]; then
                echo "Neutron member size mismatch: $relative_path" >&2
                exit 1
              fi

              actual_blob=$(git hash-object --no-filters "$source_path")
              if [[ "$actual_blob" != "$expected_blob" ]]; then
                echo "Neutron member identity mismatch: $relative_path" >&2
                exit 1
              fi

              if [[ "$destination" != "-" ]]; then
                install -Dm0444 "$source_path" "$import_root/$destination"
              fi
            done

            store_path=$(nix-store --add-fixed --recursive sha256 "$import_root")
            echo "Imported the four approved Neutron runtime members as $store_path"
            echo "Keep this path local; do not publish it or dependent outputs to a public cache."
    '';
    meta = {
      description = "License-gated importer for the pinned i.MX95 Neutron runtime members";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  }
