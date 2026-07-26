{
  alsa-utils,
  coreutils,
  gnugrep,
  lib,
  writeShellApplication,
}:
writeShellApplication {
  name = "frdm-imx95-audio-smoke";
  runtimeInputs = [
    alsa-utils
    coreutils
    gnugrep
  ];
  text = builtins.readFile ../scripts/frdm-imx95-audio-smoke;
  meta = {
    description = "Stable-card onboard MICFIL audio smoke runner for FRDM-i.MX95";
    license = lib.licenses.mit;
    platforms = ["aarch64-linux"];
  };
}
