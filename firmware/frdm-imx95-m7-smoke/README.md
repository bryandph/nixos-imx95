# FRDM-i.MX95 M7 Embassy smoke firmware

This original MIT-licensed application is the harmless first firmware slice
for the FRDM-i.MX95 M7 remoteproc workflow.

It uses Embassy's Cortex-M executor, the version-pinned `bsp-frdm-imx95`
crate, and the BSP's architectural `SysTick` future. If System Manager has
already assigned and configured the board's LPUART3 console, it emits:

- an immutable firmware identity at startup;
- a monotonically wrapping architectural-tick heartbeat; and
- a status-only response when any input byte is received.

It never sends SCMI or System Manager power commands, creates an RPMsg device,
uses DMA, or changes A55 state. UART polls are bounded. If the UART
precondition is absent, timer/executor operation continues silently rather
than touching clocks or pin muxes that the M7 does not own.

The firmware includes a version-1 remoteproc resource table with zero entries.
It is linked into the reviewed 256 KiB ITCM/DTCM layout supplied by the BSP and
must remain an ELF image for Linux remoteproc.
