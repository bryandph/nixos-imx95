# FRDM-i.MX95 M7 Embassy smoke firmware

This original MIT-licensed application is the harmless first firmware slice
for the FRDM-i.MX95 M7 remoteproc workflow.

It uses Embassy's Cortex-M executor, the version-pinned `bsp-frdm-imx95`
crate, and the BSP's architectural `SysTick` future. The reviewed System
Manager policy assigns MU5, LPUART3, and the two console pads to the M7. At
startup the BSP uses CRC32-protected SMT requests over MU5 to set the LPUART3
clock and route those pads, then emits:

- an immutable firmware identity at startup;
- a monotonically wrapping architectural-tick heartbeat; and
- a startup policy line identifying M7-local WFI and disabled A55 control;
- M7-local wait-for-interrupt after every heartbeat; and
- a harmless response when any input byte is received.

The WFI affects only the M7 core and uses the already-running SysTick
interrupt as its bounded wake source. It never sends SCMI or System Manager
power commands, creates an RPMsg device, uses DMA, or changes A55 state. UART
polls are bounded. If the UART
precondition is absent or System Manager rejects initialization, the firmware
fails closed into M7-local wait-for-interrupt without sending power commands.

A55 suspend/wake remains disabled. The reviewed NXP example coordinates that
operation through System Manager plus SRTM/RPMsg, while this TCM-only public
firmware has no validated Linux suspend transaction, LM1 authorization,
armed A55 wake source, or out-of-band recovery contract. The public firmware
therefore exposes no A55 suspend operation and does not emit an A55-affecting
SMT request.

The firmware includes a version-1 remoteproc resource table with zero entries.
It is linked into the reviewed 256 KiB ITCM/DTCM layout supplied by the BSP and
must remain an ELF image for Linux remoteproc. The Cortex-M reset runtime
zeroes the full DTCM before Rust data initialization so the i.MX95 TCM ECC is
valid before the stack reaches previously untouched lines.
