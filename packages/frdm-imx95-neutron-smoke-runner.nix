{
  coreutils,
  gnugrep,
  jq,
  lib,
  python3,
  writeShellApplication,
}:
writeShellApplication {
  name = "frdm-imx95-neutron-smoke";
  runtimeInputs = [
    coreutils
    gnugrep
    jq
    python3
  ];
  text = builtins.readFile ../scripts/frdm-imx95-neutron-smoke;
  meta = {
    description = "Bounded, evidence-producing FRDM-i.MX95 Neutron smoke runner";
    license = lib.licenses.mit;
    platforms = ["aarch64-linux"];
  };
}
