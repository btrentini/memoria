# Memoria

Memoria is a native macOS performance monitor and process manager built with Swift 6, SwiftUI, AppKit and Swift Charts. It targets ARM64 Macs running macOS 26 or later.

**Memoria app v.10** is a development source snapshot under verification. See the [release notes](Documentation/ReleaseNotes-v.10.md). The [requirements ledger](Documentation/Requirements.md) distinguishes implemented source, verified behaviour, unfinished features and external gates. There is no signed or notarised release.

The app uses an original brain-inspired identity, with [light, dark, monochrome and small-size assets](Branding/README.md). The native Icon Composer source is included; its system rendering remains an external verification gate.

The source includes twelve monitoring views, native flat/tree process tables and an inspector, application grouping, a menu-bar popover, Quick Task Manager, bounded histories, aggregate export/recording, memory alerts, native socket discovery and reviewed process actions. CPU, memory, process, network, volume, battery and thermal providers use system APIs. Optional measurements have explicit unavailable states.

Use the **Simple / Full** control in the main toolbar to switch layouts. Simple shows charts, key readings and up to ten processes ranked by a chosen resource metric. Selecting a process opens its inspector in Full view. The choice is remembered, and the detailed view retains its own filters and columns. The same option is available in Settings → General.

Every tab includes a ranked process table. Choose CPU, memory footprint, resident memory, threads, read/write rates, PID, owner or state; click a column heading or use the ranking controls to change the order. Search and combine scope, state, CPU and memory filters. Each tab remembers its own controls; search text remains in memory for the session. GPU, network and power attribution stays explicitly unavailable where no validated process provider exists.

The [menu-bar monitor and desktop widgets](Documentation/Widgets.md) provide compact CPU and memory readings. Settings → General controls the menu-bar display and local widget sharing. Small and medium desktop widgets show timestamped snapshots; activation and shared-container access require matching App Group signatures and remain unverified here.

Termination revalidates start time, boot session and executable identity. SIGTERM never escalates automatically. SIGKILL and tree operations require explicit scope review. Free Port checks ownership, observes exit and re-scans for remaining/replacement listeners. POSIX signalling still has a residual PID race; see the [threat model](Documentation/ThreatModel.md).

Administrator operations and the isolated Rust sensor worker are disabled by default. A signed helper, separate authorisation and live verification are required for administrator use. Endpoint Security remains conditional on Apple entitlement approval. There are no accounts, analytics, remote telemetry, HTTP server, automatic downloads or fan control.

Build the stable modules with Swift Package Manager or open Memoria.xcodeproj. Start with the [build instructions](Documentation/Build.md); the inspected Xcode installation requires first-launch component repair before its project launcher works.

    swift build
    swift test
    swift run MemoriaProbe

Recorded results: 55 Swift tests, two Rust tests, native CPU/memory workloads and offline worker compilation. The GUI launch is unresolved; see [verification](Documentation/Verification.md) and [known issues](Documentation/KnownIssues.md).

Further documentation: [architecture and formulas](Documentation/Architecture.md), [capabilities](Documentation/Capabilities.md), [dependency audit](Documentation/DependencyAudit.md), [acceptance plan](Documentation/Acceptance.md) and [distribution gates](Documentation/Distribution.md).

Original code is [MIT licensed](LICENSE). Optional third-party code retains its own notices.

A separate [App Store submission template](AppStore/README.md) now includes a sandboxed monitoring target, metadata drafts, privacy manifests and archive/export scripts. It excludes process management and private/privileged collectors. The template and local preview are not a signed App Store submission.

Memoria now opens quietly in the menu bar. Choose **Open Memoria** from the brain status item. Settings includes optional Dock visibility and launch at login; see [background startup](Documentation/Background.md). Updated brain artwork and size/appearance guidance are in [Branding](Branding/README.md).
