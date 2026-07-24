{
  coreutils,
  gnugrep,
  iproute2,
  lib,
  stdenv,
  systemd,
  util-linux,
  writeShellApplication,
}:
writeShellApplication {
  name = "frdm-imx95-m7-ctl";

  runtimeInputs =
    [
      coreutils
      gnugrep
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      iproute2
      systemd
      util-linux
    ];

  text = builtins.readFile ../scripts/frdm-imx95-m7-ctl;

  meta = {
    description = "Guarded FRDM-i.MX95 M7 remoteproc lifecycle and UART test tool";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
