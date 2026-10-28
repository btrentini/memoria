# Architecture and measurement semantics

Memoria is a local macOS application. Its default build uses Swift 6, SwiftUI, AppKit, Swift Charts and a small C bridge to the macOS SDK. It has no accounts, analytics, remote telemetry, HTTP server, automatic downloads or fan control. The optional Rust worker is a separate executable; the stable application builds without Rust.

    Mach / libproc / Foundation / IOKit.ps
                  |
        Serial utility executors
                  |
       TelemetryCoordinator actor
                  |
        Bounded state and history
                  |
       SwiftUI + NSTableView
                  |
      Explicit action/scope review
                  |
      Identity and executable check
                  |
      Local signal or optional XPC helper
                  |
          Bounded exit observation

MemoriaCore contains sendable value types, accounting, port queries, histories and policy. MemoriaNative owns C ABI details. MemoriaCollectors performs blocking system work on serial utility queues; each executor admits at most sixteen operations, and cancelled queued work is skipped. Actors coordinate scheduling and publish streams retaining only the newest update. MemoriaServices contains process actions, bounded subprocess handling, recording, experimental-worker supervision and the administrator boundary. AppModel holds presentation state on the main actor.

The menu-bar monitor shares AppModel's current readings and histories. A WidgetPublisher actor coalesces aggregate snapshots into a bounded App Group cache through MemoriaWidgetSupport. The separate, sandboxed MemoriaWidget extension reads that cache and supplies timestamped WidgetKit timelines. It links no collectors, services, helper or worker. The support module uses a serial utility queue for bounded file access; snapshot validation and freshness remain independent of presentation. See [widget storage, scheduling and signing](Widgets.md).

## CPU

System and per-core values use successive host_processor_info snapshots. User, system and idle are shares of the total tick delta; nice ticks are included in user time. A reset, wrap, changed core count or zero interval discards the interval. Core indices have no unverified P/E labels.

PROC_PIDTASKINFO totals are Mach absolute ticks. The C bridge converts them using mach_timebase_info with a 128-bit intermediate, before exposing nanoseconds. Process CPU is 100 × change in user/system nanoseconds ÷ elapsed nanoseconds. One occupied logical core is 100%, so a multi-threaded process can exceed 100%. The inspector separately divides by discovered logical-core count for machine-normalised CPU. Sampling uses system uptime. Sleep clears baselines.

## Memory

Page counts are multiplied by Mach's page size. Active, inactive, wired, compressor storage, free, speculative and purgeable values retain their own labels. The overview's accounted memory is active + wired + compressor physical storage. This named accounting sum does not claim Activity Monitor equivalence. Purgeable can overlap other categories; free pages are not the whole of available memory.

The Memory tab presents this accounting sum prominently as **Memory used**, alongside installed RAM, its percentage and a usage bar. The formula remains visible below the total. Full and Simple layouts, including the Store edition, share this summary. Swap and operating-system pressure remain separate; unavailable or inconsistent capacity readings do not produce a fabricated percentage.

Swap comes from vm.swapusage. Pressure comes from public Dispatch notifications; before the first notification it is unknown, rather than inferred from occupancy. Process resident memory and footprint are separate fields. Application footprint totals are process-accounting sums and may count shared physical pages repeatedly.

## Processes, applications and sockets

Identity contains PID, start seconds/microseconds and boot-session UUID (or the public kernel boot-time fallback). If both boot queries fail, actions are unavailable. Actions also retain executable path, device and inode. Task/resource/executable failures preserve their original error code. Multi-call snapshots re-query start time afterwards. Polling cannot detect every exec of the same executable; signalling is not atomic with identity checking.

An executable under an app bundle has exact observed bundle-path membership. Descendant associations are inferred; shared services remain unassigned. This does not establish bundle-identifier verification.

Socket discovery reads libproc descriptors and validates the process again afterwards. TCP listeners are distinguished from established connections; UDP, IPv4 and IPv6 remain separate. Scans have descriptor, output and elapsed-time bounds. Permission/race failures remain visible. A bounded, explicit-argument lsof fallback is available on demand. Its records require matching process identity and executable snapshots from before and after lsof.

Free Port re-scans before signalling, limits the operation to reviewed identities, observes termination and scans again. Replacement processes are reported and never added automatically. A partial scan cannot prove a port is free.

## Storage and networking

Volume capacities are displayed individually. Shared APFS capacity is never added across volumes. Process I/O rates are libproc accounting deltas, not physical-device traffic. Storage-driver rates use the documented IOBlockStorageDriver Statistics keys, separately per registry service. Missing keys remain unavailable; these counters do not establish NAND-level traffic.

Traffic is displayed per interface. Names and flags classify physical, loopback, tunnel and virtual interfaces, with no aggregate that counts VPN traffic twice. Name-based physical classification is an interpretation, not a topology proof. Counter decreases and interface identity changes reset the baseline.

## Bounded state and privacy

Aggregate history retains at most 3,601 samples per metric for one hour, with at most 128 metric histories. Time-bucket downsampling preserves missing-value buckets. Detailed CPU/footprint history is limited to the selected identity and at most eight pinned identities; it is not persistently recorded. Arguments and environments never enter routine history or recording. Recording is opt-in, limited to 25 MB and seven days, and can be deleted. Exports state their aggregate-only scope.

Default intervals are one second for aggregates, two seconds for visible process enumeration, ten seconds for background processes and thirty seconds for volumes. Background, battery power, Low Power Mode and elevated thermal states reduce sampling. Ports refresh on demand. Native calls can still be delayed by the operating system.

## External interfaces

Worker protocol version 1 uses newline-delimited JSON, a handshake, strict sequences, capability announcements, finite values, unit-specific ranges and monotonic timing. The GUI verifies the bundled executable's signature and uses a minimal environment. Startup/read deadlines, bounded stderr, a message-rate limit, cancellation and three launch attempts limit failure impact. Private sensor APIs stay outside the GUI. The worker pauses when no visible GPU, power or diagnostics view needs its readings.

The helper accepts typed JSON envelopes in Data arguments, with 64 KiB limits and one target per request. Both XPC ends require exact identifiers and the configured team. A handshake precedes transient authorisation material. The helper independently checks age, replay, authorisation and identity. Missing signing configuration fails closed. Signed installation and adversarial peer testing remain release gates.

CPU units were checked against [Apple XNU recount tests](https://github.com/apple-oss-distributions/xnu/blob/main/tests/recount/recount_perf_tests.c). Native fixtures independently compare the converted process CPU against getrusage after child exit. No Apple implementation code was copied.
