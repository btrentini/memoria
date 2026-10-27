#!/bin/sh
set -eu
cd "$(dirname "$0")/../Worker"
case "$(rustc --version)" in
    "rustc 1.95.0 "*) ;;
    *) printf '%s\n' 'Use the audited Rust 1.95.0 toolchain. This script does not install or download a compiler.' >&2; exit 1 ;;
esac
cargo build --locked --offline --release --target aarch64-apple-darwin
printf '%s\n' 'Built optional worker. Signing, bundling and independent hardware validation are separate release gates.'
