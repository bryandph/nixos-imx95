#![no_std]
#![no_main]
#![deny(unsafe_op_in_unsafe_fn)]

use bsp_frdm_imx95::{
    system_manager::SystemManager,
    timer::{self, SYSTICK_MAX_RELOAD, SysTickTicker},
    uart::{Config, Lpuart3, PollingUart},
};
use cortex_m_rt::exception;
use embassy_executor::Spawner;
use panic_halt as _;

const BANNER: &[u8] = b"frdm-imx95-m7-smoke v0.1.0\r\n";
const HEARTBEAT: &[u8] = b"heartbeat architectural-tick=";
const INPUT_IGNORED: &[u8] = b"input ignored; status-only demo\r\n";

#[repr(C, align(16))]
struct ResourceTable {
    version: u32,
    entries: u32,
    reserved: [u32; 2],
}

#[used]
#[unsafe(link_section = ".resource_table")]
static RESOURCE_TABLE: ResourceTable = ResourceTable {
    version: 1,
    entries: 0,
    reserved: [0; 2],
};

#[exception]
fn SysTick() {
    timer::on_systick_interrupt();
}

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    let _ = spawner;
    let Some(peripherals) = cortex_m::Peripherals::take() else {
        idle_forever();
    };
    let Ok(ticker) = SysTickTicker::start(peripherals.SYST, SYSTICK_MAX_RELOAD) else {
        idle_forever();
    };

    let Some(mut uart) = initialize_uart() else {
        idle_forever();
    };
    let _ = write_all(&mut uart, BANNER);
    let _ = uart.flush();

    let mut heartbeat = 0_u32;
    loop {
        ticker.wait_ticks(1).await;
        heartbeat = heartbeat.wrapping_add(1);

        let _ = write_all(&mut uart, HEARTBEAT);
        let _ = write_u32(&mut uart, heartbeat);
        let _ = write_all(&mut uart, b"\r\n");

        if matches!(uart.try_read(), Ok(Some(_))) {
            let _ = write_all(&mut uart, INPUT_IGNORED);
        }

        let _ = uart.flush();
    }
}

#[allow(unsafe_code)]
fn initialize_uart() -> Option<Lpuart3> {
    // SAFETY: The reviewed remoteproc System Manager policy assigns the M7's
    // MU5 A-side channel, LPUART3, GPIO_IO14, and GPIO_IO15 to this firmware.
    let mut system_manager = unsafe { SystemManager::take() }?;
    // SAFETY: The same policy grants exclusive LPUART3 and console-pad access
    // to this single-core firmware.
    let uart = unsafe { Lpuart3::take() }?;
    uart.initialize(&mut system_manager, Config::default()).ok()
}

fn write_all<U: PollingUart>(uart: &mut U, bytes: &[u8]) -> Result<(), U::Error> {
    for &byte in bytes {
        uart.write(byte)?;
    }
    Ok(())
}

fn write_u32<U: PollingUart>(uart: &mut U, mut value: u32) -> Result<(), U::Error> {
    let mut digits = [0_u8; 10];
    let mut cursor = digits.len();

    if value == 0 {
        return uart.write(b'0');
    }

    while value != 0 {
        cursor -= 1;
        digits[cursor] = b'0' + u8::try_from(value % 10).unwrap_or(0);
        value /= 10;
    }

    write_all(uart, &digits[cursor..])
}

fn idle_forever() -> ! {
    loop {
        cortex_m::asm::wfi();
    }
}
