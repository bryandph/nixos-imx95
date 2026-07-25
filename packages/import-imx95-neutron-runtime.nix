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
      (runtime.license.file // {fileName = "-";})
      (runtime.license.contentRegister // {fileName = "-";})
      (runtime.sbom // {fileName = "-";})
      (runtime.members.firmware
        // {
          fileName = builtins.baseNameOf runtime.members.firmware.path;
        })
      (runtime.members.driver
        // {
          fileName = builtins.baseNameOf runtime.members.driver.path;
        })
    ]
    ++ map (
      header:
        header
        // {
          fileName = builtins.baseNameOf header.path;
        }
    )
    runtime.members.headers;
  recordLines =
    lib.concatMapStringsSep "\n" (
      record: "    ${lib.escapeShellArg "${record.path}|${record.blobSha1}|${record.sha256 or "-"}|${toString record.size}|${record.fileName}"}"
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

            imported=0
            for record in "''${records[@]}"; do
              IFS='|' read -r relative_path expected_blob expected_sha256 expected_size file_name <<<"$record"
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

              if [[ "$file_name" != "-" ]]; then
                actual_sha256=$(sha256sum "$source_path" | cut -d' ' -f1)
                if [[ "$actual_sha256" != "$expected_sha256" ]]; then
                  echo "Neutron member SHA-256 mismatch: $relative_path" >&2
                  exit 1
                fi

                store_path=$(nix-store --add-fixed sha256 "$source_path")
                echo "Imported $file_name as $store_path"
                ((imported += 1))
              fi
            done

            if [[ "$imported" -ne 4 ]]; then
              echo "Expected to import four Neutron runtime members; imported $imported" >&2
              exit 1
            fi
            echo "Keep these paths local; do not publish them or dependent outputs to a public cache."
    '';
    meta = {
      description = "License-gated importer for the pinned i.MX95 Neutron runtime members";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  }
