# FRDM-i.MX95 M7 remoteproc testing

The M7 experiment is an optional SD-boot test. It does not alter the accepted
eMMC installation or start the M7 automatically.

## Preconditions

1. Connect the host to the board's J1 debug connector. The CH344 bridge should
   expose four serial ports.
2. Keep the A55 SSH connection available on Ethernet.
3. Build and write the
   `packages.aarch64-linux.frdm-imx95-m7-remoteproc-sd-image` image to a
   specifically identified SD card.
4. Select SD boot and cold boot the board. Do not overwrite the eMMC baseline.

J1 is attached to the NixOS host `cm5devkit`, not to the operator's macOS
machine. The bridge is present there as USB device `1a86:55d5` and provides
these persistent by-id paths:

```text
/dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_0123456789-if00
/dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_0123456789-if02
/dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_0123456789-if04
/dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_0123456789-if06
```

A harmless blank-line probe identifies `if00` as the A55 console and `if02` as
the System Manager debug monitor. Hardware testing with the M7-owned LPUART3
route confirms `if04` as the M7 console; `if06` is the unused fourth channel.
Both remain quiet while the M7 is offline.

## Identify and capture the M7 UART

List the CH34x ports on the UART host:

```console
ssh cm5devkit frdm-imx95-m7-ctl uart-list
```

Do not rely on volatile `ttyACM` numbering. Open the confirmed `if04` by-id
path at 115200 baud, 8 data bits, no parity, and one stop bit before starting
the M7. The complete observed mapping is:

- `if00` carries the A55 Linux boot console and login;
- `if02` carries early System Manager messages and its debug monitor;
- `if04` is quiet until remoteproc starts, then prints
  `frdm-imx95-m7-smoke v0.2.0`;
- `if06` is the spare channel.

Capture a selected port:

```console
ssh -t cm5devkit frdm-imx95-m7-ctl uart \
  /dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_0123456789-if04 \
  m7-uart-if04.log
```

The confirmed by-id identity is stable across tty renumbering; the currently
observed `/dev/ttyACM2` alias is not.

## Verify SD boot before touching remoteproc

The accepted installation uses eMMC. Prove the test boot is on SD and that the
optional device-tree node exists:

```console
findmnt -n -o SOURCE,FSTYPE,TARGET / /boot
for device in /sys/class/block/mmcblk*/device/type; do
  printf '%s: ' "$device"
  cat "$device"
done
frdm-imx95-m7-ctl status
```

`status` resolves the M7 by the `fsl,imx95-cm7` device-tree compatible string.
It deliberately does not accept a `remoteprocN` argument.

## Lifecycle acceptance

Start the packaged Embassy smoke firmware:

```console
sudo frdm-imx95-m7-ctl start
```

The command validates that
`frdm-imx95/frdm-imx95-m7-smoke.elf` belongs to the current system firmware
closure, starts only the identified M7 remote processor, and waits for the
`running` state. A repeated `start` with the same firmware is harmless.

Run three bounded stop/start cycles and leave the M7 running for UART
inspection:

```console
sudo frdm-imx95-m7-ctl cycle 3
frdm-imx95-m7-ctl diagnose
```

Recovery is also idempotent from an offline or running M7:

```console
sudo frdm-imx95-m7-ctl recover
```

If the kernel reports a crashed remote processor, `recover` uses the driver's
recovery control, returns the M7 to offline, selects the packaged firmware, and
starts it again. Every transition has a 15-second timeout.

For each cycle, retain the M7 UART log and the output of `diagnose`. Acceptance
requires six online A55 CPUs, no failed systemd units, working SCMI and OP-TEE,
working Ethernet/SSH, and unchanged eMMC recovery media.

## M7-local idle and A55 power boundary

The public demo reports
`m7-local-idle=wfi; a55-power-control=disabled` at startup. After every
heartbeat it executes Cortex-M wait-for-interrupt on the M7 only; the existing
SysTick interrupt wakes it for the next iteration. Acceptance requires
continued heartbeats, remoteproc state `running`, an unchanged A55 boot ID,
and zero failed units.

Any UART input byte receives a harmless status-only response. The NXP
compatibility demo coordinates A55 power through System Manager and SRTM/RPMsg,
but the public TCM-only workflow has not validated a Linux suspend transaction,
LM1 authorization, an armed A55 wake source, or out-of-band recovery. The
public firmware therefore exposes no A55 suspend command and sends no
A55-affecting System Manager request.

## Failure and rollback

On failure, do not reboot immediately. Capture:

```console
frdm-imx95-m7-ctl diagnose
sudo journalctl -k -b --no-pager
```

Then stop the M7 if it is running:

```console
sudo frdm-imx95-m7-ctl stop
```

Rollback is a cold boot with the board returned to the retained eMMC boot
selection. The optional module never modifies the boot container or eMMC.
