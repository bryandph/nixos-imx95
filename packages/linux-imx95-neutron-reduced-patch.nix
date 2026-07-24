{
  diffutils,
  fetchFromGitHub,
  gzip,
  gnutar,
  lib,
  linuxPackages_latest,
  runCommand,
  xz,
}: let
  release = import ./imx95-lf-6.18.20-2.0.0.nix {inherit lib;};
  nxpSource = fetchFromGitHub release.neutron.kernel.nxpReference.fetchFromGitHub;
  upstreamSource = linuxPackages_latest.kernel.src;
  overlay = ./imx95-15x15-frdm-neutron.dtso;
in
  runCommand "linux-imx95-neutron-reduced.patch" {
    nativeBuildInputs = [
      diffutils
      gzip
      gnutar
      xz
    ];
    passthru = {
      inherit nxpSource upstreamSource;
      inventory = release.neutron.kernel.delta;
    };
  } ''
    mkdir -p source old new
    tar -xf ${upstreamSource} -C source --strip-components=1

    for path in \
      drivers/staging/Kconfig \
      drivers/staging/Makefile \
      drivers/remoteproc/Kconfig \
      drivers/remoteproc/Makefile \
      arch/arm64/boot/dts/freescale/Makefile
    do
      mkdir -p "old/$(dirname "$path")" "new/$(dirname "$path")"
      cp "source/$path" "old/$path"
      cp "source/$path" "new/$path"
    done

    cp -R ${nxpSource}/drivers/staging/neutron new/drivers/staging/
    cp ${nxpSource}/drivers/remoteproc/imx_neutron_rproc.c \
      new/drivers/remoteproc/imx_neutron_rproc.c
    cp ${overlay} \
      new/arch/arm64/boot/dts/freescale/imx95-15x15-frdm-neutron.dtso

    sed -i \
      '/^endif # STAGING/i source "drivers/staging/neutron/Kconfig"\n' \
      new/drivers/staging/Kconfig
    printf '\nobj-$(CONFIG_NEUTRON)\t\t+= neutron/\n' \
      >> new/drivers/staging/Makefile
    sed -i '/^endif # REMOTEPROC/i \
    config IMX_NEUTRON_REMOTEPROC\n\
    \ttristate "i.MX neutron remoteproc support"\n\
    \tdepends on ARCH_MXC\n\
    \thelp\n\
    \t  Say Y here to support the i.MX Neutron NPU through remoteproc.\n' \
      new/drivers/remoteproc/Kconfig
    printf '\nobj-$(CONFIG_IMX_NEUTRON_REMOTEPROC)\t+= imx_neutron_rproc.o\n' \
      >> new/drivers/remoteproc/Makefile
    cat >> new/arch/arm64/boot/dts/freescale/Makefile <<'EOF'

    imx95-15x15-frdm-neutron-dtbs := imx95-15x15-frdm.dtb imx95-15x15-frdm-neutron.dtbo
    dtb-$(CONFIG_ARCH_MXC) += imx95-15x15-frdm-neutron.dtb
    EOF

    find old new -exec touch --date=@1 {} +
    diff -urN old new > "$out" || test "$?" -eq 1
  ''
