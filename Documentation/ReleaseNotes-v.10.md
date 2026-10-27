# Memoria app v.10

27 October 2026 · Initial development source snapshot · MIT licence

Memoria is a native performance monitor and process manager for ARM64 Macs running macOS 26 or later. This publication includes the application source, tests, original artwork, documentation and pinned optional worker dependencies. It is not a signed, notarised or runtime-accepted production release. The publication name is v.10; the development bundle version remains 0.1.0.

## Included

- Twelve monitoring destinations with ranked, sortable and filterable process lists. CPU, memory footprint, resident memory, threads and available I/O rates have separate rankings; unavailable attribution remains labelled.
- Simple and Full layouts. Simple combines charts and key readings with up to ten measured processes; Full provides flat/tree tables, application grouping and an inspector.
- Native CPU, memory, process, interface, volume, battery and thermal-pressure providers, with bounded histories, aggregate exports, optional recording and memory alerts.
- Reviewed process-action flows: normal application quit, SIGTERM, confirmed SIGKILL, selected trees and Free Port. Identity revalidation, exit observation and replacement-listener checks are implemented. Signals never automatically escalate; POSIX signalling retains a documented identity race.
- A configurable menu-bar monitor, Quick Task Manager and small/medium WidgetKit extension. Widget sharing is opt-in and contains aggregate readings only.
- A recognisable brain icon with default, dark and monochrome artwork, standard/Retina Dock and Finder sizes, optically simplified menu/control templates and Icon Composer source.
- Background operation with no Dock icon or automatic monitor window by default, optional Dock visibility, and native opt-in launch-at-login controls.
- A separate sandboxed monitoring edition and App Store submission template. The template is not ready for upload: developer signing, provisioning and listing details remain pending.
- An isolated experimental sensor worker and an optional authenticated administrator helper, both disabled by default. Missing signing configuration fails closed. Endpoint Security remains conditional on Apple's approval.

## Verification and remaining gates

The SDK-explicit Swift/C builds, Swift tests, native workload checks, Rust tests and vendor-integrity results are described in [Verification.md](Verification.md). [PublicationChecks.json](../Evidence/PublicationChecks.json) records checks repeated against the publishing checkout. Build success does not establish live UI behaviour.

Xcode project execution remains unresolved in the tested environment. The App Store preview has passed local menu-bar, quiet-launch, open/close-window and Dock-toggle checks; this does not establish the full direct edition’s live acceptance. Live accessibility, shortcuts, menu-bar/widget activation, signed App Group sharing and system icon appearance require further verification. M2 Pro identity and advanced sensor accuracy have not been established. Controlled Free Port, signed cross-user operations, Endpoint Security, Instruments profiling and an actual eight-hour soak also remain open. Developer ID signing, notarisation and distribution acceptance have not passed.

See the [requirements ledger](Requirements.md) and [known issues](KnownIssues.md) for individual status and scope.

## Publication privacy

Raw process/socket captures, captured PIDs, personal workspace paths, machine identifiers, credentials, signing material, build products and runtime recordings are excluded. PID-handling source and synthetic identity tests remain necessary parts of the process manager. Source and dependency scanning found no confirmed credentials; Cargo checksum matches were reviewed and verified as hashes. See [Publication.md](Publication.md) for the audit scope and limits.

Memoria has no accounts, analytics, remote telemetry, HTTP server, automatic downloads or fan control.
