# Requirements ledger

The supplied plan is the source of intent. The original numbered brief (sections 1–56) was not supplied; its wording is not reconstructed or claimed as audited. This ledger splits the supplied plan into individually reviewable entries and preserves its section-to-phase references.

Status: Not started → Implemented → Verified, or Blocked externally / Unavailable on tested platform. Implemented means source exists, not that it compiled or ran. Each verification must name evidence and scope. An optional unavailable state can satisfy a fallback requirement without satisfying the measurement requirement.

## Numbered-brief traceability

| Section | Plan phases |
|---|---|
| 1 | 0 |
| 2 | 0, 5 |
| 3 | 0, 5 |
| 4 | 0, 5, 7 |
| 5 | 0, 5, 7 |
| 6 | 0 |
| 7 | 1, 8 |
| 8 | 1, 8 |
| 9 | 1, 2, 8 |
| 10 | 1, 8 |
| 11 | 1, 8 |
| 12 | 2, 8 |
| 13 | 2, 8 |
| 14 | 2, 8 |
| 15 | 3, 6 |
| 16 | 6 |
| 17 | 3, 6 |
| 18 | 3, 6 |
| 19 | 3 |
| 20 | 4 |
| 21 | 4 |
| 22 | 4 |
| 23 | 2 |
| 24 | 2, 8 |
| 25 | 5 |
| 26 | 5 |
| 27 | 5 |
| 28 | 5 |
| 29 | 4 |
| 30 | 4 |
| 31 | 2, 5 |
| 32 | 2, 5 |
| 33 | 2, 8 |
| 34 | 0, 6, 9 |
| 35 | 0, 6, 9 |
| 36 | 0, 7, 9 |
| 37 | 0, 9 |
| 38 | 0, 2, 8, 9 |
| 39 | 0, 2, 8, 9 |
| 40 | 0, 1 |
| 41 | 0 |
| 42 | 1 |
| 43 | 2 |
| 44 | 3 |
| 45 | 4 |
| 46 | 5 |
| 47 | 6 |
| 48 | 7 |
| 49 | 1, 8 |
| 50 | 9 |
| 51 | 9 |
| 52 | 9 |
| 53 | 9 |
| 54 | 9 |
| 55 | 9 |
| 56 | 9 |

## Phase 0

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P0.01 | Record OS, SDK, compiler and architecture | Evidence/Environment.json | 1 | Tool version queries | Observed Xcode 27.1, SDK 27.0, Swift 6.4, macOS 26.7.1, ARM64 | Verified |
| P0.02 | Independently establish M2 Pro hardware | Evidence/Environment.json | 1 | Hardware query | Hardware model query denied; logical cores and RAM do not identify a chip | Blocked externally |
| P0.03 | Writable access to retained memoria repository | Documentation/Build.md | 1 | Write check | Renamed repository outside current writable roots; staging used | Blocked externally |
| P0.04 | Inspect six upstream repositories at immutable commits | Documentation/DependencyAudit.md | 1 | Source and manifest review | Commit/file inventory recorded; audit limits explicit | Implemented |
| P0.05 | Record licences and integration decisions | Documentation/DependencyAudit.md | 1 | Licence review | No GPL code incorporated | Implemented |
| P0.06 | Audit adopted transitive dependencies and build scripts | Documentation/DependencyAudit.md | 1 | Pinned worker dependency review | Vendored source/build-script review and offline locked build complete; see dependency audit limits | Implemented |
| P0.07 | Generate SPDX inventory and attribution | Documentation/SBOM.spdx.json | 1 | JSON and inventory checks | Documentation/SBOM.spdx.json generated from resolved lock; ThirdPartyNotices/NOTICE.md; cross-reference validation and 1,024 vendor digests. | Verified |
| P0.08 | Scan dependencies for advisories | Documentation/DependencyAudit.md | 1 | OSV query batch | Evidence/osv-query.json and osv-response.json: no OSV matches for fourteen exact registry versions; Git/private-API coverage excluded. | Verified |
| P0.09 | Document capability/provider matrix | Documentation/Capabilities.md | 1 | Source/API mapping | Measurement and fallback distinguished | Implemented |
| P0.10 | Document architecture and privilege threat model | Documentation/Architecture.md; Documentation/ThreatModel.md | 1 | Design review | Residual signalling race documented | Implemented |
| P0.11 | Inspect SDK process, resource and socket declarations | Sources/MemoriaNative | 1 | Strict C compilation | C bridge compiled with -Wall -Wextra -Werror | Verified |
| P0.12 | Establish commands, evidence and granular ledger | Documentation/Build.md; Documentation/Requirements.md | 1 | Project/ledger validation | Ledger does not equate compile with runtime | Implemented |
| P0.13 | MIT licence for original code | LICENSE | 1 | Licence inspection | Original code licence present | Verified |

## Phase 1

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P1.01 | Checked-in Xcode app target and shared schemes | Memoria.xcodeproj | 1 | plutil and xcodebuild | Source present; verification pending | Implemented |
| P1.02 | Separate helper and disposable-fixture targets | Helper; Fixtures; Package.swift | 1 | Independent target builds | Source present; verification pending | Implemented |
| P1.03 | Local package modules with Swift 6 concurrency checking | Package.swift; Sources | 1 | Debug/Release warnings-as-errors build | Source present; verification pending | Implemented |
| P1.04 | Native sidebar, content and inspector regions | App/Views.swift | 1 | XCUITest and interactive resize | Source present; verification pending | Implemented |
| P1.05 | All twelve navigation destinations | App/AppModel.swift; App/Views.swift | 1 | Navigation smoke | Source present; verification pending | Implemented |
| P1.06 | Native typography and semantic light/dark appearance | App/Views.swift; App/SettingsView.swift | 1 | Appearance/accessibility inspection | Source present; verification pending | Implemented |
| P1.07 | Menu-bar entry and popover | App/MemoriaApp.swift; App/ProcessViews.swift | 1 | Menu lifecycle smoke | Source present; verification pending | Implemented |
| P1.08 | Reusable Quick Task Manager window | App/AppModel.swift; App/ProcessViews.swift | 1 | Warm presentation and repeated open/close | Source present; verification pending | Implemented |
| P1.09 | Configurable Control–Shift shortcut and conflict status | App/GlobalShortcut.swift | 1 | Conflict/disable/key-change checks | Source present; verification pending | Implemented |
| P1.10 | Preserve system Force Quit shortcut | App/GlobalShortcut.swift | 1 | Registered modifier/key inspection | Source present; verification pending | Implemented |
| P1.11 | Persist column dimensions, visibility and quick-window frame | App/ProcessViews.swift; App/AppModel.swift | 1 | Relaunch preferences test | Source present; verification pending | Implemented |
| P1.12 | Confine synthetic data to tests/fixtures | Tests; Fixtures | 1 | Production source inspection | Source present; verification pending | Implemented |
| P1.13 | Launch, keyboard focus and window smoke | UITests | 1 | Interactive app test | Source present; verification pending | Implemented |

## Phase 2

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P2.01 | Enumerate processes with PID/start/boot identity | Sources/MemoriaNative/native.c; NativeReader.swift | 1 | Native probe and identity tests | Source present; verification pending | Implemented |
| P2.02 | Collect owner, ancestry, path, state, threads and start time | Sources/MemoriaCollectors/NativeReader.swift | 1 | Disposable-process inspection | Source present; verification pending | Implemented |
| P2.03 | Collect CPU time, RSS and physical footprint | Sources/MemoriaNative/native.c | 1 | Controlled CPU/memory workloads | Evidence/README.md (local log withheld); Evidence/README.md (local log withheld). One/two-thread CPU and footprint checks; no independent chip-model claim. | Verified |
| P2.04 | Preserve task/resource/path errors per process | Sources/MemoriaCollectors/NativeReader.swift | 1 | Denied/fast-exit tests | Source present; verification pending | Implemented |
| P2.05 | Collect process I/O accounting where exposed | Sources/MemoriaNative/native.c; TelemetryCoordinator.swift | 1 | Counter/rate tests | Source present; verification pending | Implemented |
| P2.06 | Lazy arguments without routine recording | Sources/MemoriaCollectors/NativeReader.swift; App/AppModel.swift | 1 | Argument privacy/revalidation test | Source present; verification pending | Implemented |
| P2.07 | Invalidate process deltas when executable changes | Sources/MemoriaCollectors/TelemetryCoordinator.swift | 1 | Exec identity tests | Source present; verification pending | Implemented |
| P2.08 | Collect host/per-core user/system/idle deltas | Sources/MemoriaNative/native.c; MemoriaCore/Metrics.swift | 1 | Accounting and native probe | Evidence/README.md (local log withheld) and native-tests.txt: 12 host CPU counters sampled; Evidence/README.md (local log withheld) tests delta arithmetic and reset handling. GUI and independent host-load comparison remain open. | Verified |
| P2.09 | Discover core count and avoid unverified P/E labels | App/Views.swift; SystemCollector.swift | 1 | Core-count inspection | Evidence/README.md (local log withheld): 12 cores reported. Presentation source uses core indices without inferred P/E assignments; chip identity remains unavailable. | Verified |
| P2.10 | Collect one/five/fifteen-minute load averages | Sources/MemoriaCollectors/SystemCollector.swift | 1 | Native probe | Source present; verification pending | Implemented |
| P2.11 | One-core process percentages and labelled machine-normalisation | MemoriaCore/Metrics.swift; App/ProcessViews.swift | 1 | 200% CPU arithmetic test | Evidence/README.md (local log withheld); Evidence/README.md (local log withheld). One/two-thread CPU and footprint checks; no independent chip-model claim. | Verified |
| P2.12 | Memory components and documented accounting formulas | SystemCollector.swift; Documentation/Architecture.md | 1 | Accounting review/native probe | Source present; verification pending | Implemented |
| P2.13 | Swap, cumulative page activity and pressure notifications | SystemCollector.swift; TelemetryCoordinator.swift | 1 | Pressure/workload checks | Source present; verification pending | Implemented |
| P2.14 | Keep available memory distinct from free memory | App/Views.swift; Documentation/Architecture.md | 1 | Copy/formula review | Source present; verification pending | Implemented |
| P2.15 | Group exact bundle paths and inferred ancestry | MemoriaCore/Processes.swift; App/Views.swift | 1 | Grouping tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P2.16 | Keep shared/unassigned services separate | MemoriaCore/Processes.swift | 1 | Shared-service fixture | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P2.17 | Label application footprints as accounting sums | App/Views.swift | 1 | Copy review | Source present; verification pending | Implemented |
| P2.18 | Sortable virtualised table and basic filters | App/ProcessViews.swift; MemoriaCore/Processes.swift | 1 | 5,000-row benchmark | Source present; verification pending | Implemented |
| P2.19 | Inspector with copy/reveal/actions and resource details | App/ProcessViews.swift | 1 | Selection/fast-exit smoke | Source present; verification pending | Implemented |
| P2.20 | Bound history and incremental sampling publication | History.swift; TelemetryCoordinator.swift | 1 | Bounds/stream capacity checks | Source present; verification pending | Implemented |
| P2.21 | Run system calls away from MainActor on bounded executors | Sources/MemoriaCollectors/NativeReader.swift | 1 | Concurrency review/profile | Source present; verification pending | Implemented |
| P2.22 | Lazy signing metadata and open-file inspection | Sources/MemoriaServices/ProcessDetails.swift | 1 | Identity-bound detail tests | Bounded five-second cache with before/after revalidation | Implemented |
| P2.23 | Configurable collapsible process tree table | App/ProcessOutline.swift | 1 | Tree navigation/large-table test | Virtualised NSOutlineView; interactive verification outstanding | Implemented |

## Phase 3

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P3.01 | Normal application quit remains distinct from signals | Sources/MemoriaServices/ProcessActions.swift | 1 | Disposable app normal-quit test | Source present; verification pending | Implemented |
| P3.02 | SIGTERM and explicit confirmed SIGKILL | Actions.swift; ProcessActions.swift; ActionConfirmation | 1 | Action tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.03 | Revalidate start, boot and executable before every signal | Sources/MemoriaServices/ProcessActions.swift | 1 | Stale/reused PID and exec tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.04 | Reject invalid PIDs, PID 1 and own infrastructure | Sources/MemoriaCore/Actions.swift | 1 | Invalid/excluded-target tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.05 | Review fixed children-first tree membership | Processes.swift; App/ProcessViews.swift | 1 | Cycle/order/scope tests | Source present; verification pending | Implemented |
| P3.06 | Exclude inferred/shared helpers initially | App/ProcessViews.swift | 1 | Tree confirmation review | Source present; verification pending | Implemented |
| P3.07 | Revalidate every selected tree target | ProcessActions.swift | 1 | Partial tree failure test | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.08 | Report survivors without expanding termination scope | App/AppModel.swift | 1 | Spawn/reparent fixture | Source present; verification pending | Implemented |
| P3.09 | Never automatically escalate SIGTERM | ProcessActions.swift | 1 | Ignored-TERM test | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.10 | Observe exit separately from signal delivery | ProcessActions.swift | 1 | Still-running/exit/denial tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.11 | Preserve errno without assuming SIP protection | ProcessActions.swift; Documentation/ThreatModel.md | 1 | EPERM tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.12 | Generate fixed numeric Terminal commands without execution | Actions.swift; App/ProcessViews.swift | 1 | Command construction test | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P3.13 | Explain copied-command and final TOCTOU limitations | Documentation/ThreatModel.md; App/ProcessViews.swift | 1 | Copy review | Source present; verification pending | Implemented |

## Phase 4

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P4.01 | Validate port formats/ranges including bracketed IPv6 and URLs | Sources/MemoriaCore/Ports.swift | 1 | PortTests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P4.02 | Inspect libproc socket descriptors before fallback | Sources/MemoriaCollectors/PortCollector.swift | 1 | IPv4/IPv6/UDP fixtures | Source present; verification pending | Implemented |
| P4.03 | Bound lsof runtime, output and cancellation | Sources/MemoriaServices/BoundedCommand.swift | 1 | Timeout/flood/parser tests | Evidence/README.md (local log withheld): controlled policy/parser/backend tests. Live GUI, Free Port and privileged acceptance remain separate gates. | Verified |
| P4.04 | Distinguish wildcard/loopback binds and TCP client states | Ports.swift; native.c | 1 | Established false-match tests | Source present; verification pending | Implemented |
| P4.05 | Cache scans and avoid one-second full-system lsof | PortCollector.swift; App/AppModel.swift | 1 | Scheduling inspection | Source present; verification pending | Implemented |
| P4.06 | Free Port confirms identity, terminates and re-scans | ProcessActions.swift; App/ProcessViews.swift | 1 | Listener removal and replacement tests | Source present; verification pending | Implemented |
| P4.07 | Report incomplete coverage and replacement listeners | Ports.swift; ProcessActions.swift | 1 | Permission/race tests | Source present; verification pending | Implemented |
| P4.08 | Display physical/virtual/loopback/tunnel interface counters | SystemCollector.swift; App/Views.swift | 1 | Counter/reset/churn/VPN tests | Source present; verification pending | Implemented |
| P4.09 | Avoid duplicate aggregate interface totals | App/Views.swift; Documentation/Architecture.md | 1 | Aggregation review | Source present; verification pending | Implemented |
| P4.10 | Display mounted internal/external volume capacities | SystemCollector.swift; App/Views.swift | 1 | Volume/APFS checks | Source present; verification pending | Implemented |
| P4.11 | Do not sum shared APFS capacity | App/Views.swift | 1 | Accounting review | Source present; verification pending | Implemented |
| P4.12 | Port-aware search and inspector sockets | App/AppModel.swift; App/ProcessViews.swift | 1 | Quick-window search test | Source present; verification pending | Implemented |
| P4.13 | Validated physical-device disk-activity provider | Sources/MemoriaCollectors/DiskCollector.swift | 1 | Controlled physical-device I/O comparison | Documented per-driver counters implemented; physical-device/reference comparison outstanding | Implemented |

## Phase 5

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P5.01 | Pinned macmon library worker with app features disabled | Worker/Cargo.toml; Worker/Cargo.lock | 2 | Locked ARM64 cargo build | Evidence/README.md (local log withheld); Evidence/README.md (local log withheld): ARM64 --locked --offline build; no CLI/server dependency path. | Verified |
| P5.02 | Private APIs remain outside the GUI | Worker; Package.swift | 2 | Link/symbol inspection | Source present; verification pending | Implemented |
| P5.03 | Verify exact bundled worker path and code signature | ExperimentalProvider.swift | 2 | Wrong identity/missing worker tests | Source present; verification pending | Implemented |
| P5.04 | Minimal environment and compatible handshake | ExperimentalProvider.swift; WorkerProtocol.swift | 2 | Protocol version tests | Source present; verification pending | Implemented |
| P5.05 | Bound stdout/stderr, message size, rate and buffering | ExperimentalProvider.swift; WorkerProtocol.swift | 2 | Flood/oversize tests | Source present; verification pending | Implemented |
| P5.06 | Startup/read deadlines and limited restart backoff | ExperimentalProvider.swift | 2 | Timeout/restart exhaustion tests | Source present; verification pending | Implemented |
| P5.07 | Stop on disable, parent exit and worker failure | ExperimentalProvider.swift; Worker/src/main.rs | 2 | Lifecycle/crash tests | Source present; verification pending | Implemented |
| P5.08 | Discover channels before interpreting zero | Worker/src/main.rs; WorkerProtocol.swift | 2 | Missing-counter tests | Source present; verification pending | Implemented |
| P5.09 | Validate finite/range/unit/time and hardware/OS compatibility | Worker/src/main.rs; WorkerProtocol.swift | 2 | Range/protocol tests | Source present; verification pending | Implemented |
| P5.10 | GPU active residency separately from scaled activity | Worker/src/main.rs; App/Views.swift | 2 | Matched Metal workload/reference | Source present; verification pending | Implemented |
| P5.11 | CPU/GPU/DRAM/ANE power only with available channels | Worker/src/main.rs | 2 | Idle/CPU/ANE comparison | Source present; verification pending | Implemented |
| P5.12 | Temperature/fan values remain optional and bounded | Worker/src/main.rs | 2 | Missing-sensor tests | Source present; verification pending | Implemented |
| P5.13 | Do not invent ANE utilisation or dedicated VRAM | App/Views.swift | 2 | Metric semantics review | Source present; verification pending | Implemented |
| P5.14 | Per-metric provider, tier, quality and diagnostics | Metrics.swift; WorkerProtocol.swift | 2 | Provenance round trip | Source present; verification pending | Implemented |
| P5.15 | Stable UI survives optional-provider absence | App/Views.swift; SettingsView.swift | 2 | Missing worker smoke | Source present; verification pending | Implemented |
| P5.16 | Independent-reference disagreement reporting | App/Views.swift; Documentation/Capabilities.md | 2 | Matched metric/provider comparison | No validated independent reference; comparison remains explicitly unverified | Blocked externally |
| P5.17 | Independent M2 Pro idle/CPU/Metal validation | Fixtures/MetalWorkload.swift | 2 | Matched reference measurement | Hardware identity and independent measurements not established | Blocked externally |
| P5.18 | Per-process GPU/network attribution feasibility | Documentation/Capabilities.md | 2 | Defensible attribution source | No validated attribution source; shown unavailable | Blocked externally |
| P5.19 | Validated lock resolution and complete worker dependency audit | Worker/Cargo.lock | 2 | cargo --locked and source/advisory audit | Offline resolution/build, two Rust tests and 1,024 file digests verified; security audit coverage limited as documented | Implemented |

## Phase 6

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P6.01 | Optional SMAppService bundled daemon, disabled by default | Administrator.swift; Configuration | 3 | Signed registration-state tests | Source present; verification pending | Implemented |
| P6.02 | Approval-pending/enabled/denied/unavailable/removal feedback | Administrator.swift; App/SettingsView.swift | 3 | Service state lifecycle | Source present; verification pending | Implemented |
| P6.03 | Demand-driven XPC and bounded helper lifetime | Helper/main.swift; launchd plist | 3 | Idle/activation profile | Source present; verification pending | Implemented |
| P6.04 | Exact identifier/team validation on both XPC ends | AdministratorClient.swift; Helper/main.swift | 3 | Wrong signer/team tests | Source present; verification pending | Implemented |
| P6.05 | Authenticate reply before sending authorisation form | AdministratorClient.swift | 3 | Untrusted peer/handshake tests | Source present; verification pending | Implemented |
| P6.06 | Independently authorise each one-target request | Administrator.swift | 3 | Missing/expired/revoked authorisation | Source present; verification pending | Implemented |
| P6.07 | Keep externalised authorisation transient and unlogged | AdministratorClient.swift | 3 | Code/log inspection | Source present; verification pending | Implemented |
| P6.08 | Independently re-query target identity inside helper | Administrator.swift; ProcessActions.swift | 3 | Helper stale-target tests | Source present; verification pending | Implemented |
| P6.09 | Fixed SIGTERM/SIGKILL only; no arbitrary execution | Administrator.swift; Actions.swift | 3 | Unsupported operation decode tests | Source present; verification pending | Implemented |
| P6.10 | Age, replay, size and version checks | Administrator.swift | 3 | Helper policy tests | Source present; verification pending | Implemented |
| P6.11 | Fail closed when signing credentials absent | Administrator.swift; Helper/main.swift | 3 | Unsigned refusal test | Evidence/README.md (unsigned helper refused to listen, exit 78): helper refused to listen and exited 78 with no signing team configured. Signed peer-validation and installation remain unverified. | Verified |
| P6.12 | Unregister/remove helper from Settings | Administrator.swift; App/SettingsView.swift | 3 | Signed removal test | Source present; verification pending | Implemented |
| P6.13 | Signed installation, cross-user actions and revocation | Documentation/Distribution.md | 3 | Isolated signed-system tests | Developer ID credentials and isolated account/system unavailable | Blocked externally |
| P6.14 | Fixed-purpose powermetrics only after validation | — | 3 | Schema/overhead/authorisation validation | Not exposed. Privileged schema/overhead validation and signed operation review required before implementation. | Blocked externally |
| P6.15 | Full cancellation/upgrade/revocation audit semantics | Administrator.swift; AdministratorClient.swift | 3 | Interrupted operations and upgrade tests | Cancellation, bounded in-memory audit and protocol mismatch handling present; signed revocation/lifecycle verification blocked | Implemented |

## Phase 7

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P7.01 | Event-provider value abstraction and replay reconciliation | Sources/MemoriaCore/ProcessEventProvider.swift; Sources/MemoriaCore/Actions.swift | 4 | IdentityTests | Source present; verification pending | Implemented |
| P7.02 | Dropped-event gap triggers polling reconciliation | Sources/MemoriaCore/Actions.swift | 4 | Event gap test | Source present; verification pending | Implemented |
| P7.03 | Separately signed notification-only system extension | — | 4 | Live fork/exec/exit events | Conditional on Apple entitlement/provisioning | Blocked externally |
| P7.04 | Authenticated extension communication and bounded retention | — | 4 | Malformed/gap/event-retention tests | Extension not instantiated without provisioning | Blocked externally |
| P7.05 | Activation, TCC, revocation and complete removal | — | 4 | Isolated system lifecycle | Apple-approved provisioning unavailable | Blocked externally |
| P7.06 | Retain polling when ES absent | TelemetryCoordinator.swift; App/Views.swift | 4 | Missing capability smoke | Source present; verification pending | Implemented |
| P7.07 | Exclude GPL reference implementations from MIT code | Documentation/DependencyAudit.md | 4 | Dependency/source inventory | Source present; verification pending | Implemented |

## Phase 8

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P8.01 | Complete real-provider or unavailable states on all screens | App/Views.swift | 1 | Navigation/empty-state smoke | Source present; verification pending | Implemented |
| P8.02 | Command palette and process context menus | App/ProcessViews.swift | 1 | Keyboard/menu checks | Source present; verification pending | Implemented |
| P8.03 | Copy/reveal controls and tooltips | App/ProcessViews.swift | 1 | Inspection-action smoke | Source present; verification pending | Implemented |
| P8.04 | 60-second, 5-minute, 15-minute and one-hour history windows | History.swift; App/Views.swift | 1 | History/downsampling tests | Source present; verification pending | Implemented |
| P8.05 | Time-aware downsampling with gaps | Sources/MemoriaCore/History.swift | 1 | Clock/gap tests | Source present; verification pending | Implemented |
| P8.06 | Bound aggregate histories and metric cardinality | History.swift; App/AppModel.swift | 1 | Bounds/churn tests | Source present; verification pending | Implemented |
| P8.07 | Opt-in persistent recording with quota/retention/deletion | Recording.swift; App/SettingsView.swift | 1 | Quota/recovery/delete tests | Source present; verification pending | Implemented |
| P8.08 | JSON/CSV aggregate-only export with explicit scope | History.swift; App/AppModel.swift | 1 | Export round trip | Source present; verification pending | Implemented |
| P8.09 | Exclude arguments/sensitive metadata from routine logs | Recording.swift; App/AppModel.swift | 1 | Privacy inspection | Source present; verification pending | Implemented |
| P8.10 | Configurable alerts with hysteresis and notification permission | History.swift; App/AppModel.swift; SettingsView.swift | 1 | Alert/denied-permission tests | Source present; verification pending | Implemented |
| P8.11 | Reduce work when hidden, in Low Power Mode or thermally constrained | TelemetryCoordinator.swift; App/AppModel.swift | 1 | Sampling/profile tests | Source present; verification pending | Implemented |
| P8.12 | Pause/rebaseline on sleep and preserve chart gaps | TelemetryCoordinator.swift; App/AppModel.swift | 1 | Sleep/resume test | Source present; verification pending | Implemented |
| P8.13 | Continue menu-bar and alert aggregate collection | TelemetryCoordinator.swift | 1 | Background sampling check | Source present; verification pending | Implemented |
| P8.14 | Native keyboard/accessibility conventions and semantic appearance | App | 1 | VoiceOver/keyboard/reduced-transparency checks | Source present; verification pending | Implemented |
| P8.15 | Detailed history for selected/pinned processes only | App/AppModel.swift; App/Views.swift | 1 | Retention and pin lifecycle tests | Selected identity plus at most eight pinned identities; interactive verification outstanding | Implemented |
| P8.16 | Exhaustive VoiceOver, resize and reduced-motion verification | UITests; App | 1 | Interactive acceptance | App aborts during macOS registration; Xcode UI runner also blocked by missing component | Blocked externally |
| P8.17 | Ranked, sortable and filterable process lists in every tab | App/Views.swift; App/ProcessViews.swift; Sources/MemoriaCore/ProcessRanking.swift | 1 | RankingTests; MemoriaUITests | Evidence/RankingVerification.json; Evidence/README.md (local log withheld) and swift-tests-debug.txt: core ranking tests pass. SDK compilation and UI-test type-checking pass; live dashboard/table acceptance remains blocked by GUI launch. | Implemented |
| P8.18 | Independent tab ranking controls, sensible defaults and missing-last ordering | Sources/MemoriaCore/Processes.swift; Sources/MemoriaCore/ProcessRanking.swift; App/AppModel.swift | 1 | RankingTests | Evidence/RankingVerification.json; Evidence/README.md (local log withheld) and swift-tests-debug.txt: core ranking tests pass. SDK compilation and UI-test type-checking pass; live dashboard/table acceptance remains blocked by GUI launch. | Implemented |
| P8.19 | Optional simplified main-window view with charts and top ten processes | App/SimpleDashboardView.swift; App/Views.swift; App/SettingsView.swift | 1 | TopProcessesTests; MemoriaUITests | Evidence/SimplifiedViewVerification.json: both compiler builds pass; UI test source type-checks. Live layout, switching, persistence and accessibility acceptance remain blocked by the existing GUI launch issue. | Implemented |
| P8.20 | Top-ten summary ranks measured resources before limiting rows | Sources/MemoriaCore/TopProcesses.swift | 1 | TopProcessesTests | Tests/MemoriaCoreTests/TopProcessesTests.swift; Evidence/README.md (local log withheld) and swift-tests-debug.txt: zero to 5,000 rows, correct highest ten, missing/invalid exclusion, measured zero, stable ties and associated-application scope. | Verified |
| P8.21 | Configurable menu-bar readings and chart popover | App/MenuBarMonitor.swift; App/SettingsView.swift; App/MemoriaApp.swift | 1 | WidgetTests; interactive menu/window lifecycle | Evidence/WidgetVerification.json: menu formatting tests and compilation pass. Preferences, appearance and window lifecycle require live GUI acceptance. | Implemented |
| P8.22 | Small and medium macOS WidgetKit extension | Widget/MemoriaWidget.swift; Memoria.xcodeproj; Configuration | 1 | Extension compiler/link checks; signed gallery acceptance | Evidence/WidgetVerification.json: Debug/optimised extension compiles and links only its aggregate support module and system frameworks. Gallery activation and signed-container delivery remain unverified. | Implemented |
| P8.23 | Bounded private widget cache with explicit freshness and safe navigation | Sources/MemoriaWidgetSupport; App/WidgetPublisher.swift | 1 | WidgetTests | Tests/MemoriaCoreTests/WidgetTests.swift; Evidence/README.md (local log withheld) and swift-tests-debug.txt. Model/store checks cover schema, privacy keys, nil/zero, size, cadence, cache permissions/deletion and navigation-only URLs. This verifies local policy, not live OS App Group or widget delivery. | Verified |
| P8.24 | Original brain mark with light, dark and small-size bitmap exports | Branding; Scripts/build-icons.py; Scripts/export-icons.swift | 1 | ImageIO size/profile/alpha and ICNS round trips; visual proof | Evidence/IconVerification.json and IconImageMetadata.json; Branding/Preview.png. 60 PNGs checked, three ICNS files each decoded with ten 1x/2x representations, small-size artwork visually reviewed. This does not verify native Icon Composer or live OS appearance. | Verified |
| P8.25 | Brain identity in application, widget and menu bar | App/BrandMark.swift; App/Resources; Widget/MemoriaWidget.swift; Memoria.xcodeproj | 1 | Compiler, resource and bundle checks; live UI acceptance | System-coloured alpha templates; default ICNS in development bundle | Implemented |
| P8.26 | Layered Icon Composer source with default, dark and mono annotations | Branding/Memoria.icon; Scripts/generate-project.py | 1 | Native document build and appearance review | Unmasked foreground and separate background; native decoding/rendering not verified | Implemented |

## Phase 9

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| P9.01 | Debug and Release Xcode builds without first-party warnings | Memoria.xcodeproj | 1 | xcodebuild | Xcode missing CoreSimulator component; direct compilation is separate evidence | Blocked externally |
| P9.02 | Swift core and provider build verification | Scripts/direct-build.py | 1 | SDK-explicit warnings-as-errors build | Evidence/README.md (local log withheld) and release-build.txt: SDK-explicit ARM64 Swift 6 builds with strict concurrency and warnings as errors; Xcode project build remains separately blocked. | Verified |
| P9.03 | Run complete automated acceptance suite | Tests; UITests | 1 | Swift Testing/XCTest/Rust | 55 Swift tests in each Debug/optimised-library run and 2 Rust tests passed; native CPU/memory/owned-child checks passed. XCUITest, live widgets, Free Port and signed/hardware scenarios remain unverified. | Implemented |
| P9.04 | Validate clean checkout and locked dependency build | Scripts; Worker/Cargo.lock | 1 | Clean rebuild | Actual repository remains unwritable; locked worker build verified in staging | Blocked externally |
| P9.05 | Profile CPU/allocations/contention/leaks/energy in Instruments | — | 1 | Foreground/background Instruments profile | Interactive profiling environment required | Blocked externally |
| P9.06 | Measure warm Quick Task Manager p95 below 200 ms | UITests | 1 | Repeated warm-presentation benchmark | GUI launch aborts during macOS registration; no valid presentation measurement. | Blocked externally |
| P9.07 | Measure 5,000-row search/filter p95 below 100 ms | Tests/MemoriaCoreTests/CoreTests.swift | 1 | Filter benchmark | Evidence/README.md (local log withheld) and swift-tests-debug.txt: 5,000-row core filter/sort passes 100 ms p95; full UI search response and M2 Pro performance remain unverified. | Implemented |
| P9.08 | Measure monitoring CPU budgets and baseline footprint | — | 1 | M2 Pro foreground/background profile | Hardware validation/profile not established | Blocked externally |
| P9.09 | Run eight-hour soak for queues/descriptors/tasks/processes | — | 1 | Real eight-hour run | GUI runtime not established. Simulated history bounds are tested but do not substitute for a real soak. | Blocked externally |
| P9.10 | Verify Slack grouping, resource changes and quit in controlled session | — | 1 | User-approved disposable Slack session | Requires a controlled interactive session; personal Slack was not terminated. | Blocked externally |
| P9.11 | Test other-user/protected-process boundaries safely | — | 1 | Dedicated isolated account/system | Not authorised on everyday processes | Blocked externally |
| P9.12 | Sign nested executables and app with Hardened Runtime | Memoria.xcodeproj; Documentation/Distribution.md | 1 | Developer ID archive | No signing identity | Blocked externally |
| P9.13 | Notarise, staple and verify Gatekeeper externally | Documentation/Distribution.md | 1 | Clean external installation | No credentials/distribution artefact | Blocked externally |
| P9.14 | Test installation, upgrades, helper revocation and uninstall | Documentation/Distribution.md | 1 | Distributed-package lifecycle | Signed package and isolated system required | Blocked externally |
| P9.15 | Deliver README/build/threat/audit/SBOM/notices/compatibility/issues | Documentation; README.md | 1 | Documentation cross-check | Source delivery | Implemented |
| P9.16 | Assess reduced App Store edition | Documentation/Distribution.md | 1 | Distribution assessment | No App Store eligibility claim | Implemented |
| P9.17 | Verify signed widget gallery and shared App Group delivery | Documentation/Widgets.md; Configuration | 1 | Signed widget installation and lifecycle | No configured signing identity; GUI launch unresolved | Blocked externally |
| P9.18 | Verify native icon rendering and system appearance selection | Branding/README.md; Evidence/README.md | 1 | Icon Composer, Dock, Finder and dark/tinted/clear checks | LaunchServices FileWrapper error on Apple's own template; asset compiler and GUI environment unresolved | Blocked externally |

## Brain icon and background follow-up

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| BG.01 | Recognisable brain artwork across app, Dock, widget and menus | Branding masters, Icon Composer source, ICNS, catalog and alpha templates | 1 | 71 PNG checks; 10 representations per ICNS; visual proof | Evidence/IconVerification.json | Verified for exported assets; native renderer remains gated |
| BG.02 | Run without a Dock icon or initial monitor window | LSUIElement; shared accessory lifecycle; suppressed launch scene | 1 | App Store live launch and menu/window lifecycle | Evidence/BackgroundVerification.json | Verified in local App Store preview; direct UI pending |
| BG.03 | Continue monitoring after closing the window | Application delegate and persistent menu-bar scene | 1 | Open/close monitor and observe continued menu readings | Evidence/BackgroundVerification.json | Verified in local App Store preview |
| BG.04 | Optional native login startup and Dock visibility | MemoriaLifecycle; mainApp registration; preferences and revocation states | 1 | Five lifecycle policy tests; settings UI check | Evidence/BackgroundVerification.json | Implemented; policy tests verified; permanent installation/login test blocked externally |

## User installation and contributor onboarding

| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |
|---|---|---|---|---|---|---|
| U.01 | User instructions first, developer/contributor instructions second | README.md; CONTRIBUTING.md | 1 | Local link and command review | Documentation source | Implemented |
| U.02 | Complete development app with executable permissions and portable libraries | Makefile; Scripts/doctor.py; Scripts/verify-app.py | 1 | Clean-checkout app/test workflow and bundle verification | Per-preview build manifest and release notes | Implemented |
| U.03 | Finder installation ZIP with provenance and checksums | Scripts/package-preview.py; Scripts/build_support.py | 1 | Dirty/stale/partial rejection; archive extraction and integrity | Per-preview manifest; unsigned preview is not a production-release pass | Implemented |
| U.04 | Normal signed consumer installation | Documentation/Distribution.md | 1 | Developer ID, notarisation, external Gatekeeper and installation checks | Signing credentials absent; full installation acceptance pending | Blocked externally |
