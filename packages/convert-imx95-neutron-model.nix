{
  coreutils,
  gitMinimal,
  lib,
  nix,
  writeShellApplication,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  converter = release.neutron.converter;
  model = release.neutron.model;
in
  writeShellApplication {
    name = "convert-imx95-neutron-model";
    runtimeInputs = [
      coreutils
      gitMinimal
      nix
    ];
    text = ''
      usage() {
        cat >&2 <<'EOF'
      usage:
        convert-imx95-neutron-model --accept-license \
          /path/to/${converter.file} \
          /path/to/neutron-converter \
          /path/to/${model.sourceArchive.member} \
          [expected-converted-sha256]

      Without the final hash, the tool performs two deterministic conversions
      and reports the candidate identity without importing the result. Review
      and pin that identity, then rerun with the hash to import only the
      verified converted model into the local Nix store.
      EOF
      }

      if [[ $# -lt 4 || $# -gt 5 || "$1" != "--accept-license" ]]; then
        usage
        exit 2
      fi

      wheel=$(realpath "$2")
      converter_exe=$(realpath "$3")
      source_model=$(realpath "$4")
      expected_converted_hash="''${5:-}"

      test -f "$wheel"
      test -x "$converter_exe"
      test -f "$source_model"

      test "$(sha256sum "$wheel" | cut -d' ' -f1)" = ${converter.sha256}
      test "$(sha256sum "$source_model" | cut -d' ' -f1)" = \
        ${model.sourceArchive.memberSha256}
      "$converter_exe" --version | grep -F ${lib.escapeShellArg converter.version} >/dev/null

      work_dir=$(mktemp -d "''${TMPDIR:-/tmp}/imx95-neutron-model.XXXXXX")
      trap 'rm -rf -- "$work_dir"' EXIT
      first="$work_dir/${model.name}-neutron-a.tflite"
      second="$work_dir/${model.name}-neutron-b.tflite"

      for output in "$first" "$second"; do
        env LC_ALL=C TZ=UTC "$converter_exe" \
          --input="$source_model" \
          --output="$output" \
          --target=${model.converted.target} \
          --force-determinism
      done

      first_hash=$(sha256sum "$first" | cut -d' ' -f1)
      second_hash=$(sha256sum "$second" | cut -d' ' -f1)
      if [[ "$first_hash" != "$second_hash" ]]; then
        echo "Deterministic Neutron conversions produced different identities" >&2
        exit 1
      fi

      if [[ -z "$expected_converted_hash" ]]; then
        echo "Candidate converted model SHA-256: $first_hash"
        echo "Nothing was imported; pin this identity and rerun with it."
        exit 0
      fi

      if [[ "$first_hash" != "$expected_converted_hash" ]]; then
        echo "Converted model identity does not match the pinned SHA-256" >&2
        exit 1
      fi

      stable_model="$work_dir/${model.name}-neutron.tflite"
      install -m0444 "$first" "$stable_model"
      store_path=$(nix-store --add-fixed sha256 "$stable_model")
      echo "Imported the verified converted model as $store_path"
      echo "Keep this path local pending affirmative redistribution authority."
    '';

    meta = {
      description = "Two-pass deterministic i.MX95 Neutron model conversion and import";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
    };
  }
