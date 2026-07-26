{
  coreutils,
  gnugrep,
  lib,
  nvme-cli,
  pciutils,
  util-linux,
  writeShellApplication,
}:
writeShellApplication {
  name = "frdm-imx95-nvme-smoke";
  runtimeInputs = [
    coreutils
    gnugrep
    nvme-cli
    pciutils
    util-linux
  ];
  text = builtins.readFile ../scripts/frdm-imx95-nvme-smoke;
  meta = {
    description = "Read-only PCIe/NVMe inventory runner for FRDM-i.MX95";
    license = lib.licenses.mit;
    platforms = ["aarch64-linux"];
  };
}
