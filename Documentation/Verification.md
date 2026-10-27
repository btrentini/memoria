# Verification record

Date: 27 October 2026. Platform: ARM64 macOS 26.7.1 (25G241), Xcode 27.1, SDK 27.0, Swift 6.4 in Swift 6 language mode. Twelve logical cores and 32 GiB were observed; hardware model discovery was denied. The Git commit identifies the published source snapshot.

| Check | Outcome and scope |
|---|---|
| Swift/C compilation | SDK-explicit Debug and optimised builds from empty output directories; strict concurrency and warnings as errors. Local build logs were reviewed; this does not establish Xcode-project or GUI acceptance |
| Swift Testing | 55 tests across eleven suites: accounting, identities, reviewed tree order/partial failure, cancellation, ports, histories, quotas, worker framing and bounded subprocesses |
| Rust | Two tests passed; ARM64 Release built with locked vendored sources and offline mode |
| Vendor integrity | 1,024 file digests checked, including unchanged upstream macmon source |
| Native CPU | One busy thread about 99%; two about 197% using one-core percentages. Converted libproc times agree with independent getrusage totals within 0.3% in the recorded run |
| Native memory | Touching 32 MiB increased observed process footprint by about 32 MiB |
| Native process signal | A child created by the test was inspected, sent SIGTERM and reaped with that signal. This is not a GUI or privileged-operation acceptance test |
| Native discovery | Hundreds of processes and socket endpoints were collected; inaccessible/racing targets remained explicit |
| Worker absence | Raw worker emitted a versioned handshake, then an explicit subscription-unavailable error and exited normally, with no stderr output |
| Search | Core filtering/sorting of 5,000 synthetic rows took 6.75 ms p95 (optimised) and 16.47 ms (Debug). This excludes UI dispatch/rendering; the full UI budget remains unverified |
| History | Simulated eight-hour input remains bounded; export/recovery/quota/deletion checks pass. No real soak claim |
| GUI | Failed to launch successfully; macOS registration abort and LaunchServices error retained |
| Signing | Ad-hoc bundle integrity passed strict verification; unsigned helper refused to listen (exit 78). No Developer ID/notarisation or signed-helper pass |

The native workload fixture originally exposed a missing Mach timebase conversion in process CPU accounting. The bridge now converts ticks with a 128-bit intermediate, and the independent getrusage check prevents a recurrence. The public CPU-delta arithmetic tests alone would not have caught this provider-unit error.

The sandbox prevents controlled TCP/UDP binds. Those subchecks are reported as unavailable, not passed; real Free Port and replacement-listener scenarios remain open. Existing endpoint enumeration is read-only.

Published evidence contains sanitised summaries only. Raw process/socket captures, crash reports, compiler logs and machine-specific paths are excluded. See [publication scope](../Evidence/README.md). OSV coverage is limited to fourteen pinned registry versions and is not a security certification.

The process-ranking follow-up adds a shared table to all twelve destinations and the Quick Task Manager. Eight additional test functions cover every resource sort key, missing-last ordering, exact memory comparisons, combined filters, application scope, independent defaults, privacy and stale socket identities. The extended XCUITest source type-checks with the installed SDK's XCTest Swift overlay. Its interactive execution remains blocked; no visual or accessibility pass is inferred.

The simplified-view follow-up adds a persistent Simple/Full main-window control, contextual charts and a separate top-ten process summary. Five added test functions cover empty through 5,000-row inputs, limiting after ranking, missing/invalid values, measured zero, stable ties and application associations. The summary omits unmeasured values and labels the count; Full-view preferences are stored separately. Both clean compiler builds and all 55 Swift tests pass. The expanded UI smoke type-checks, but visual checks, switching, relaunch persistence and live chart behaviour still require an interactive launch.

The widget follow-up adds configurable menu-bar readings, an expanded chart popover and a separate small/medium WidgetKit extension. Nine shared-module test functions cover the aggregate cache, validation, privacy keys, freshness, publication limits, group identifiers, links and menu formatting. The extension has no collector/helper/worker linkage. SDK compilation and local signature checks do not establish widget-gallery activation, App Group delivery or live UI correctness; these remain signed, interactive acceptance gates. See [widget documentation](Widgets.md) and Evidence/WidgetVerification.json.

The brain-icon follow-up includes default, dark and grayscale exports, a layered Icon Composer source, and system-coloured menu/app/widget templates. Sixty PNG files passed size/profile/alpha checks; Apple ImageIO encoded and decoded all ten standard/Retina representations in each of three ICNS files. The small-size artwork proof was visually reviewed. Clean Debug/optimised SDK builds and local bundle-signature checks passed. Native Icon Composer decoding/rendering and live system appearance remain blocked; see Evidence/IconVerification.json. The preceding 55 core/service tests were not repeated for this artwork/resource change.

For the v.10 publication, the clean publishing checkout passed the SDK-explicit Debug build, all 55 Swift tests, the locked offline worker Release build and its two tests. All 1,007 retained vendor file digests matched after removal of seventeen unused CLI files. Source privacy and credential checks are recorded in [PublicationChecks.json](../Evidence/PublicationChecks.json). These checks do not change the live acceptance gates above.
