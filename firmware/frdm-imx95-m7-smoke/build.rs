//! Makes the remoteproc resource-table linker fragment available.

use std::{env, fs, path::PathBuf};

fn main() {
    let out_dir = PathBuf::from(env::var_os("OUT_DIR").expect("Cargo sets OUT_DIR"));
    fs::write(
        out_dir.join("resource-table.x"),
        include_bytes!("resource-table.x"),
    )
    .expect("copy resource-table.x to OUT_DIR");

    println!("cargo:rustc-link-search={}", out_dir.display());
    println!("cargo:rerun-if-changed=resource-table.x");
}
