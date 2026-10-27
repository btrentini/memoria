# Dependency and source audit

Audit date: 27 October 2026. The stable Swift/C application has no third-party package dependencies. Apple frameworks and libproc are system dependencies. The optional Rust worker is separate, disabled by default and not part of the stable build.

## Immutable source inventory

| Repository | Inspected commit | Root licence | Decision and inspected surface |
|---|---|---|---|
| [macmon](https://github.com/vladkens/macmon) | 39e98aa73e49256e6281b2a228f6ef3499ae3209 | MIT, copyright 2024 vladkens | Optional Rust library only. Cargo.toml/lock, LICENSE, src/lib.rs, metrics.rs, sources.rs, shared.rs and clpc.rs; application features disabled |
| [Stats](https://github.com/exelban/stats) | add62a23355863c3134513c1215e916287bb9a00 | MIT, copyright 2019 Serhiy Mytrovtsiy | Reference only; no extracted code. CPU/Sensors readers, sensor values, bridge headers, Xcode package/build-script declarations |
| [mactop](https://github.com/metaspartan/mactop) | 8dbfaaed7426cff3bcfbcb7951a2e15dfb6d1667 | MIT, copyright 2024–2026 Carsen Klock | Reference only; no Go dependency. go.mod/go.sum, native/IOReport/power/process/port file inventory |
| [Portman](https://github.com/meliharik/portman) | faf571556321275a83b1a714a183849a6694f271 | MIT, copyright 2026 Melih Arık | Reference only. PortScanner.swift, ProcessKiller.swift and app/store inventory. Memoria independently implements identity checks and explicit force confirmation |
| [TaskExplorer](https://github.com/objective-see/TaskExplorer) | 438c254e88b86a70c00a051828faafed21078bd4 | GPLv3 text | Architectural reference only; no copied/linked code. Extension process/network/XPC inventory, entitlements, signing and network/update call sites |
| [ProcInfo](https://github.com/objective-see/ProcInfo) | ec51090fcf741a9e045dd3e5119cb5cc8750efd3 | GPLv3 text in LICENSE.md | Reference only; no static library or copied code. Process/ProcessMonitor APIs, KERN_PROCARGS2 and legacy auditpipe call sites |

The inventory records inspected surfaces, not a full security audit of every file in all six projects. No upstream build script was executed as part of source inspection.

## Integration findings

macmon's default application feature includes terminal/CLI functionality, including an HTTP service. The worker disables default features and imports the library. The library uses private IOReport, IOHID and SMC interfaces through unsafe FFI. These remain inside the unprivileged worker. The GUI neither links these interfaces nor exposes fan control.

The library has a fixed system_profiler subprocess fallback when native hardware discovery fails. The supervisor uses a minimal PATH containing system directories; the worker creates its own process group and parent-death/control-pipe handling. This subprocess behaviour remains part of lifecycle verification.

Some macmon power fields default to zero when counters are missing. Memoria's adapter requires channel presence and accepted units before publishing those fields. IOReport interpretation is restricted to the intended M2 Pro/macOS 26 combination in this initial worker. Range checks and upstream support do not prove hardware accuracy; independent workload/reference validation is still required.

Stats uses native APIs, private sensor interfaces and several subprocesses; its fan-control and updater behaviour are not incorporated. Its inspected Xcode shell phases update version metadata and optionally run SwiftLint. mactop's dependency graph includes terminal, localisation and Prometheus libraries; none are adopted. Portman's original termination path automatically escalates; that behaviour is not used in Memoria. TaskExplorer has Endpoint Security, XPC and external update/VirusTotal functionality; none of its implementation is copied. ProcInfo's legacy auditpipe path is not adopted.

## Optional worker dependency graph

The expected library graph comprises macmon plus fourteen registry packages: core-foundation, core-foundation-sys, libc, serde, serde_core, serde_derive, serde_json, proc-macro2, quote, syn, unicode-ident, memchr, itoa and zmij. Exact versions and upstream archive checksums are recorded in worker-lock-packages.json and Worker/Cargo.lock.

The upstream versions were retrieved as crate archives and all fourteen SHA-256 digests matched the upstream lock. Cargo resolved the vendored graph offline, ran two worker tests successfully and built the ARM64 Release worker with --locked --offline. Worker/Cargo.lock and Documentation/worker-lock-packages.json record the linked dependency graph. No CLI/server dependencies are present. The three upstream unused-assignment warnings are retained in the build log; the original wrapper emitted no warning.

Build scripts in libc, proc-macro2, quote, serde, serde_core, serde_json and zmij were reviewed before execution. They inspect compiler/target settings, invoke the configured Rust compiler for version or feature probes, and write generated Rust files/probe outputs under Cargo OUT_DIR. The libc script also has target-specific FreeBSD/Emscripten probes, unused on this target. No download or network operation was found in these build scripts. Runtime native calls in the adopted library include Core Foundation, IOReport, IOHID/SMC and the fixed system_profiler fallback. Private interfaces and unsafe FFI still require hardware and OS validation.

OSV's query-batch endpoint returned fourteen empty result objects for these exact crate versions. The retained request and response identify the coverage. This means no advisory match was returned by that database at that time; it does not establish absence of vulnerabilities, assess unpublished macmon Git changes, or cover undocumented Apple interfaces.

## Attribution and modification records

Original Memoria code is MIT. The macmon licence is retained under ThirdPartyNotices/macmon-MIT.txt. The wrapper uses the library API. Retained macmon library source is unchanged; unused CLI/server modules and their sample process/file data are omitted. Its manifest is replaced by a library-only manifest with exact dependencies and automatic binary discovery disabled. Worker/MODIFICATIONS.md records the change; the original manifest, source digests and licence are retained. Reference-only repositories are not shipped or linked. Any vendored registry package must retain its own licence files and checksums; registry licences are separate from Memoria's MIT licence.

Documentation/SBOM.spdx.json inventories the stable app, first-party widget extension and optional worker graph. The widget adds no third-party dependency. ThirdPartyNotices/NOTICE.md retains registry licence texts. Before release, repeat advisory queries, validate any changed graph and complete hardware/supervisor/privileged acceptance. An SBOM is an inventory, not a security certificate.
