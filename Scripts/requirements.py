#!/usr/bin/env python3
"""Maintain a reviewable requirement ledger. Verification is evidence-driven, never inferred from a build."""
from pathlib import Path
import json

root=Path(__file__).resolve().parent.parent
records=[]
phase_sections={
    0:[1,2,3,4,5,6,34,35,36,37,38,39,40,41],
    1:[7,8,9,10,11,40,42,49],2:[9,12,13,14,23,24,31,32,33,38,39,43],
    3:[15,17,18,19,44],4:[20,21,22,29,30,45],5:[2,3,4,5,25,26,27,28,31,32,46],
    6:[15,16,17,18,34,35,47],7:[4,5,36,48],8:[7,8,9,10,11,12,13,14,24,33,38,39,49],
    9:list(range(34,40))+list(range(50,57))
}
def add(phase,text,path,test,status="Implemented",evidence="Source present; verification pending",tier=None):
    number=sum(r["phase"]==phase for r in records)+1
    records.append(dict(id=f"P{phase}.{number:02}",phase=phase,requirement=text,implementation=path,
                        tier=tier or (2 if phase==5 else 3 if phase==6 else 4 if phase==7 else 1),
                        tests=test,evidence=evidence,status=status))

for text,path,test,status,evidence in [
 ("Record OS, SDK, compiler and architecture","Evidence/Environment.json","Tool version queries","Verified","Observed Xcode 27.1, SDK 27.0, Swift 6.4, macOS 26.7.1, ARM64"),
 ("Independently establish M2 Pro hardware","Evidence/Environment.json","Hardware query","Blocked externally","Hardware model query denied; logical cores and RAM do not identify a chip"),
 ("Writable access to retained memoria repository","Documentation/Build.md","Write check","Blocked externally","Renamed repository outside current writable roots; staging used"),
 ("Inspect six upstream repositories at immutable commits","Documentation/DependencyAudit.md","Source and manifest review","Implemented","Commit/file inventory recorded; audit limits explicit"),
 ("Record licences and integration decisions","Documentation/DependencyAudit.md","Licence review","Implemented","No GPL code incorporated"),
 ("Audit adopted transitive dependencies and build scripts","Documentation/DependencyAudit.md","Pinned worker dependency review","Implemented","Vendored source/build-script review and offline locked build complete; see dependency audit limits"),
 ("Generate SPDX inventory and attribution","Documentation/SBOM.spdx.json","JSON and inventory checks","Implemented","Separate stable and optional dependency scope"),
 ("Scan dependencies for advisories","Documentation/DependencyAudit.md","OSV query batch","Implemented","See retained response and coverage; not a complete audit"),
 ("Document capability/provider matrix","Documentation/Capabilities.md","Source/API mapping","Implemented","Measurement and fallback distinguished"),
 ("Document architecture and privilege threat model","Documentation/Architecture.md; Documentation/ThreatModel.md","Design review","Implemented","Residual signalling race documented"),
 ("Inspect SDK process, resource and socket declarations","Sources/MemoriaNative","Strict C compilation","Verified","C bridge compiled with -Wall -Wextra -Werror"),
 ("Establish commands, evidence and granular ledger","Documentation/Build.md; Documentation/Requirements.md","Project/ledger validation","Implemented","Ledger does not equate compile with runtime"),
 ("MIT licence for original code","LICENSE","Licence inspection","Verified","Original code licence present"),
]:
    add(0,text,path,test,status,evidence)

for text,path,test in [
 ("Checked-in Xcode app target and shared schemes","Memoria.xcodeproj","plutil and xcodebuild"),
 ("Separate helper and disposable-fixture targets","Helper; Fixtures; Package.swift","Independent target builds"),
 ("Local package modules with Swift 6 concurrency checking","Package.swift; Sources","Debug/Release warnings-as-errors build"),
 ("Native sidebar, content and inspector regions","App/Views.swift","XCUITest and interactive resize"),
 ("All twelve navigation destinations","App/AppModel.swift; App/Views.swift","Navigation smoke"),
 ("Native typography and semantic light/dark appearance","App/Views.swift; App/SettingsView.swift","Appearance/accessibility inspection"),
 ("Menu-bar entry and popover","App/MemoriaApp.swift; App/ProcessViews.swift","Menu lifecycle smoke"),
 ("Reusable Quick Task Manager window","App/AppModel.swift; App/ProcessViews.swift","Warm presentation and repeated open/close"),
 ("Configurable Control–Shift shortcut and conflict status","App/GlobalShortcut.swift","Conflict/disable/key-change checks"),
 ("Preserve system Force Quit shortcut","App/GlobalShortcut.swift","Registered modifier/key inspection"),
 ("Persist column dimensions, visibility and quick-window frame","App/ProcessViews.swift; App/AppModel.swift","Relaunch preferences test"),
 ("Confine synthetic data to tests/fixtures","Tests; Fixtures","Production source inspection"),
 ("Launch, keyboard focus and window smoke","UITests","Interactive app test"),
]:
    add(1,text,path,test)

for text,path,test in [
 ("Enumerate processes with PID/start/boot identity","Sources/MemoriaNative/native.c; NativeReader.swift","Native probe and identity tests"),
 ("Collect owner, ancestry, path, state, threads and start time","Sources/MemoriaCollectors/NativeReader.swift","Disposable-process inspection"),
 ("Collect CPU time, RSS and physical footprint","Sources/MemoriaNative/native.c","Controlled CPU/memory workloads"),
 ("Preserve task/resource/path errors per process","Sources/MemoriaCollectors/NativeReader.swift","Denied/fast-exit tests"),
 ("Collect process I/O accounting where exposed","Sources/MemoriaNative/native.c; TelemetryCoordinator.swift","Counter/rate tests"),
 ("Lazy arguments without routine recording","Sources/MemoriaCollectors/NativeReader.swift; App/AppModel.swift","Argument privacy/revalidation test"),
 ("Invalidate process deltas when executable changes","Sources/MemoriaCollectors/TelemetryCoordinator.swift","Exec identity tests"),
 ("Collect host/per-core user/system/idle deltas","Sources/MemoriaNative/native.c; MemoriaCore/Metrics.swift","Accounting and native probe"),
 ("Discover core count and avoid unverified P/E labels","App/Views.swift; SystemCollector.swift","Core-count inspection"),
 ("Collect one/five/fifteen-minute load averages","Sources/MemoriaCollectors/SystemCollector.swift","Native probe"),
 ("One-core process percentages and labelled machine-normalisation","MemoriaCore/Metrics.swift; App/ProcessViews.swift","200% CPU arithmetic test"),
 ("Memory components and documented accounting formulas","SystemCollector.swift; Documentation/Architecture.md","Accounting review/native probe"),
 ("Swap, cumulative page activity and pressure notifications","SystemCollector.swift; TelemetryCoordinator.swift","Pressure/workload checks"),
 ("Keep available memory distinct from free memory","App/Views.swift; Documentation/Architecture.md","Copy/formula review"),
 ("Group exact bundle paths and inferred ancestry","MemoriaCore/Processes.swift; App/Views.swift","Grouping tests"),
 ("Keep shared/unassigned services separate","MemoriaCore/Processes.swift","Shared-service fixture"),
 ("Label application footprints as accounting sums","App/Views.swift","Copy review"),
 ("Sortable virtualised table and basic filters","App/ProcessViews.swift; MemoriaCore/Processes.swift","5,000-row benchmark"),
 ("Inspector with copy/reveal/actions and resource details","App/ProcessViews.swift","Selection/fast-exit smoke"),
 ("Bound history and incremental sampling publication","History.swift; TelemetryCoordinator.swift","Bounds/stream capacity checks"),
 ("Run system calls away from MainActor on bounded executors","Sources/MemoriaCollectors/NativeReader.swift","Concurrency review/profile"),
]:
    add(2,text,path,test)
add(2,"Lazy signing metadata and open-file inspection","Sources/MemoriaServices/ProcessDetails.swift","Identity-bound detail tests","Implemented","Bounded five-second cache with before/after revalidation")
add(2,"Configurable collapsible process tree table","App/ProcessOutline.swift","Tree navigation/large-table test","Implemented","Virtualised NSOutlineView; interactive verification outstanding")

for text,path,test in [
 ("Normal application quit remains distinct from signals","Sources/MemoriaServices/ProcessActions.swift","Disposable app normal-quit test"),
 ("SIGTERM and explicit confirmed SIGKILL","Actions.swift; ProcessActions.swift; ActionConfirmation","Action tests"),
 ("Revalidate start, boot and executable before every signal","Sources/MemoriaServices/ProcessActions.swift","Stale/reused PID and exec tests"),
 ("Reject invalid PIDs, PID 1 and own infrastructure","Sources/MemoriaCore/Actions.swift","Invalid/excluded-target tests"),
 ("Review fixed children-first tree membership","Processes.swift; App/ProcessViews.swift","Cycle/order/scope tests"),
 ("Exclude inferred/shared helpers initially","App/ProcessViews.swift","Tree confirmation review"),
 ("Revalidate every selected tree target","ProcessActions.swift","Partial tree failure test"),
 ("Report survivors without expanding termination scope","App/AppModel.swift","Spawn/reparent fixture"),
 ("Never automatically escalate SIGTERM","ProcessActions.swift","Ignored-TERM test"),
 ("Observe exit separately from signal delivery","ProcessActions.swift","Still-running/exit/denial tests"),
 ("Preserve errno without assuming SIP protection","ProcessActions.swift; Documentation/ThreatModel.md","EPERM tests"),
 ("Generate fixed numeric Terminal commands without execution","Actions.swift; App/ProcessViews.swift","Command construction test"),
 ("Explain copied-command and final TOCTOU limitations","Documentation/ThreatModel.md; App/ProcessViews.swift","Copy review"),
]:
    add(3,text,path,test)

for text,path,test in [
 ("Validate port formats/ranges including bracketed IPv6 and URLs","Sources/MemoriaCore/Ports.swift","PortTests"),
 ("Inspect libproc socket descriptors before fallback","Sources/MemoriaCollectors/PortCollector.swift","IPv4/IPv6/UDP fixtures"),
 ("Bound lsof runtime, output and cancellation","Sources/MemoriaServices/BoundedCommand.swift","Timeout/flood/parser tests"),
 ("Distinguish wildcard/loopback binds and TCP client states","Ports.swift; native.c","Established false-match tests"),
 ("Cache scans and avoid one-second full-system lsof","PortCollector.swift; App/AppModel.swift","Scheduling inspection"),
 ("Free Port confirms identity, terminates and re-scans","ProcessActions.swift; App/ProcessViews.swift","Listener removal and replacement tests"),
 ("Report incomplete coverage and replacement listeners","Ports.swift; ProcessActions.swift","Permission/race tests"),
 ("Display physical/virtual/loopback/tunnel interface counters","SystemCollector.swift; App/Views.swift","Counter/reset/churn/VPN tests"),
 ("Avoid duplicate aggregate interface totals","App/Views.swift; Documentation/Architecture.md","Aggregation review"),
 ("Display mounted internal/external volume capacities","SystemCollector.swift; App/Views.swift","Volume/APFS checks"),
 ("Do not sum shared APFS capacity","App/Views.swift","Accounting review"),
 ("Port-aware search and inspector sockets","App/AppModel.swift; App/ProcessViews.swift","Quick-window search test"),
]:
    add(4,text,path,test)
add(4,"Validated physical-device disk-activity provider","Sources/MemoriaCollectors/DiskCollector.swift","Controlled physical-device I/O comparison","Implemented","Documented per-driver counters implemented; physical-device/reference comparison outstanding")

for text,path,test in [
 ("Pinned macmon library worker with app features disabled","Worker/Cargo.toml; Worker/Cargo.lock","Locked ARM64 cargo build"),
 ("Private APIs remain outside the GUI","Worker; Package.swift","Link/symbol inspection"),
 ("Verify exact bundled worker path and code signature","ExperimentalProvider.swift","Wrong identity/missing worker tests"),
 ("Minimal environment and compatible handshake","ExperimentalProvider.swift; WorkerProtocol.swift","Protocol version tests"),
 ("Bound stdout/stderr, message size, rate and buffering","ExperimentalProvider.swift; WorkerProtocol.swift","Flood/oversize tests"),
 ("Startup/read deadlines and limited restart backoff","ExperimentalProvider.swift","Timeout/restart exhaustion tests"),
 ("Stop on disable, parent exit and worker failure","ExperimentalProvider.swift; Worker/src/main.rs","Lifecycle/crash tests"),
 ("Discover channels before interpreting zero","Worker/src/main.rs; WorkerProtocol.swift","Missing-counter tests"),
 ("Validate finite/range/unit/time and hardware/OS compatibility","Worker/src/main.rs; WorkerProtocol.swift","Range/protocol tests"),
 ("GPU active residency separately from scaled activity","Worker/src/main.rs; App/Views.swift","Matched Metal workload/reference"),
 ("CPU/GPU/DRAM/ANE power only with available channels","Worker/src/main.rs","Idle/CPU/ANE comparison"),
 ("Temperature/fan values remain optional and bounded","Worker/src/main.rs","Missing-sensor tests"),
 ("Do not invent ANE utilisation or dedicated VRAM","App/Views.swift","Metric semantics review"),
 ("Per-metric provider, tier, quality and diagnostics","Metrics.swift; WorkerProtocol.swift","Provenance round trip"),
 ("Stable UI survives optional-provider absence","App/Views.swift; SettingsView.swift","Missing worker smoke"),
]:
    add(5,text,path,test)
add(5,"Independent-reference disagreement reporting","App/Views.swift; Documentation/Capabilities.md","Matched metric/provider comparison","Blocked externally","No validated independent reference; comparison remains explicitly unverified")
add(5,"Independent M2 Pro idle/CPU/Metal validation","Fixtures/MetalWorkload.swift","Matched reference measurement","Blocked externally","Hardware identity and independent measurements not established")
add(5,"Per-process GPU/network attribution feasibility","Documentation/Capabilities.md","Defensible attribution source","Blocked externally","No validated attribution source; shown unavailable")
add(5,"Validated lock resolution and complete worker dependency audit","Worker/Cargo.lock","cargo --locked and source/advisory audit","Implemented","Offline resolution/build, two Rust tests and 1,024 file digests verified; security audit coverage limited as documented")

for text,path,test in [
 ("Optional SMAppService bundled daemon, disabled by default","Administrator.swift; Configuration","Signed registration-state tests"),
 ("Approval-pending/enabled/denied/unavailable/removal feedback","Administrator.swift; App/SettingsView.swift","Service state lifecycle"),
 ("Demand-driven XPC and bounded helper lifetime","Helper/main.swift; launchd plist","Idle/activation profile"),
 ("Exact identifier/team validation on both XPC ends","AdministratorClient.swift; Helper/main.swift","Wrong signer/team tests"),
 ("Authenticate reply before sending authorisation form","AdministratorClient.swift","Untrusted peer/handshake tests"),
 ("Independently authorise each one-target request","Administrator.swift","Missing/expired/revoked authorisation"),
 ("Keep externalised authorisation transient and unlogged","AdministratorClient.swift","Code/log inspection"),
 ("Independently re-query target identity inside helper","Administrator.swift; ProcessActions.swift","Helper stale-target tests"),
 ("Fixed SIGTERM/SIGKILL only; no arbitrary execution","Administrator.swift; Actions.swift","Unsupported operation decode tests"),
 ("Age, replay, size and version checks","Administrator.swift","Helper policy tests"),
 ("Fail closed when signing credentials absent","Administrator.swift; Helper/main.swift","Unsigned refusal test"),
 ("Unregister/remove helper from Settings","Administrator.swift; App/SettingsView.swift","Signed removal test"),
]:
    add(6,text,path,test)
add(6,"Signed installation, cross-user actions and revocation","Documentation/Distribution.md","Isolated signed-system tests","Blocked externally","Developer ID credentials and isolated account/system unavailable")
add(6,"Fixed-purpose powermetrics only after validation","—","Schema/overhead/authorisation validation","Not started","Deliberately not exposed; validation outstanding")
add(6,"Full cancellation/upgrade/revocation audit semantics","Administrator.swift; AdministratorClient.swift","Interrupted operations and upgrade tests","Implemented","Cancellation, bounded in-memory audit and protocol mismatch handling present; signed revocation/lifecycle verification blocked")

add(7,"Event-provider value abstraction and replay reconciliation","Sources/MemoriaCore/ProcessEventProvider.swift; Sources/MemoriaCore/Actions.swift","IdentityTests","Implemented")
add(7,"Dropped-event gap triggers polling reconciliation","Sources/MemoriaCore/Actions.swift","Event gap test","Implemented")
add(7,"Separately signed notification-only system extension","—","Live fork/exec/exit events","Blocked externally","Conditional on Apple entitlement/provisioning")
add(7,"Authenticated extension communication and bounded retention","—","Malformed/gap/event-retention tests","Blocked externally","Extension not instantiated without provisioning")
add(7,"Activation, TCC, revocation and complete removal","—","Isolated system lifecycle","Blocked externally","Apple-approved provisioning unavailable")
add(7,"Retain polling when ES absent","TelemetryCoordinator.swift; App/Views.swift","Missing capability smoke","Implemented")
add(7,"Exclude GPL reference implementations from MIT code","Documentation/DependencyAudit.md","Dependency/source inventory","Implemented")

for text,path,test in [
 ("Complete real-provider or unavailable states on all screens","App/Views.swift","Navigation/empty-state smoke"),
 ("Command palette and process context menus","App/ProcessViews.swift","Keyboard/menu checks"),
 ("Copy/reveal controls and tooltips","App/ProcessViews.swift","Inspection-action smoke"),
 ("60-second, 5-minute, 15-minute and one-hour history windows","History.swift; App/Views.swift","History/downsampling tests"),
 ("Time-aware downsampling with gaps","Sources/MemoriaCore/History.swift","Clock/gap tests"),
 ("Bound aggregate histories and metric cardinality","History.swift; App/AppModel.swift","Bounds/churn tests"),
 ("Opt-in persistent recording with quota/retention/deletion","Recording.swift; App/SettingsView.swift","Quota/recovery/delete tests"),
 ("JSON/CSV aggregate-only export with explicit scope","History.swift; App/AppModel.swift","Export round trip"),
 ("Exclude arguments/sensitive metadata from routine logs","Recording.swift; App/AppModel.swift","Privacy inspection"),
 ("Configurable alerts with hysteresis and notification permission","History.swift; App/AppModel.swift; SettingsView.swift","Alert/denied-permission tests"),
 ("Reduce work when hidden, in Low Power Mode or thermally constrained","TelemetryCoordinator.swift; App/AppModel.swift","Sampling/profile tests"),
 ("Pause/rebaseline on sleep and preserve chart gaps","TelemetryCoordinator.swift; App/AppModel.swift","Sleep/resume test"),
 ("Continue menu-bar and alert aggregate collection","TelemetryCoordinator.swift","Background sampling check"),
 ("Native keyboard/accessibility conventions and semantic appearance","App","VoiceOver/keyboard/reduced-transparency checks"),
]:
    add(8,text,path,test)
add(8,"Detailed history for selected/pinned processes only","App/AppModel.swift; App/Views.swift","Retention and pin lifecycle tests","Implemented","Selected identity plus at most eight pinned identities; interactive verification outstanding")
add(8,"Exhaustive VoiceOver, resize and reduced-motion verification","UITests; App","Interactive acceptance","Blocked externally","App aborts during macOS registration; Xcode UI runner also blocked by missing component")

for text,path,test,status,evidence in [
 ("Debug and Release Xcode builds without first-party warnings","Memoria.xcodeproj","xcodebuild","Blocked externally","Xcode missing CoreSimulator component; direct compilation is separate evidence"),
 ("Swift core and provider build verification","Scripts/direct-build.py","SDK-explicit warnings-as-errors build","Implemented","See Evidence build logs"),
 ("Run complete automated acceptance suite","Tests; UITests","Swift Testing/XCTest/Rust","Implemented","Tests supplied; final outcomes recorded in Evidence"),
 ("Validate clean checkout and locked dependency build","Scripts; Worker/Cargo.lock","Clean rebuild","Blocked externally","Actual repository remains unwritable; locked worker build verified in staging"),
 ("Profile CPU/allocations/contention/leaks/energy in Instruments","—","Foreground/background Instruments profile","Blocked externally","Interactive profiling environment required"),
 ("Measure warm Quick Task Manager p95 below 200 ms","UITests","Repeated warm-presentation benchmark","Not started","No measured result"),
 ("Measure 5,000-row search/filter p95 below 100 ms","Tests/MemoriaCoreTests/CoreTests.swift","Filter benchmark","Implemented","Requires recorded successful test run"),
 ("Measure monitoring CPU budgets and baseline footprint","—","M2 Pro foreground/background profile","Blocked externally","Hardware validation/profile not established"),
 ("Run eight-hour soak for queues/descriptors/tasks/processes","—","Real eight-hour run","Not started","Simulated history bounds do not substitute for soak"),
 ("Verify Slack grouping, resource changes and quit in controlled session","—","User-approved disposable Slack session","Not started","Personal Slack was not terminated"),
 ("Test other-user/protected-process boundaries safely","—","Dedicated isolated account/system","Blocked externally","Not authorised on everyday processes"),
 ("Sign nested executables and app with Hardened Runtime","Memoria.xcodeproj; Documentation/Distribution.md","Developer ID archive","Blocked externally","No signing identity"),
 ("Notarise, staple and verify Gatekeeper externally","Documentation/Distribution.md","Clean external installation","Blocked externally","No credentials/distribution artefact"),
 ("Test installation, upgrades, helper revocation and uninstall","Documentation/Distribution.md","Distributed-package lifecycle","Blocked externally","Signed package and isolated system required"),
 ("Deliver README/build/threat/audit/SBOM/notices/compatibility/issues","Documentation; README.md","Documentation cross-check","Implemented","Source delivery"),
 ("Assess reduced App Store edition","Documentation/Distribution.md","Distribution assessment","Implemented","No App Store eligibility claim"),
]:
    add(9,text,path,test,status,evidence)

# Follow-up requested after the initial implementation hand-off.
add(8,"Ranked, sortable and filterable process lists in every tab","App/Views.swift; App/ProcessViews.swift; Sources/MemoriaCore/ProcessRanking.swift","RankingTests; MemoriaUITests","Implemented","Shared table on all twelve tabs and Quick Task Manager; live GUI acceptance remains blocked")
add(8,"Independent tab ranking controls, sensible defaults and missing-last ordering","Sources/MemoriaCore/Processes.swift; Sources/MemoriaCore/ProcessRanking.swift; App/AppModel.swift","RankingTests","Implemented","CPU, footprint, resident memory, threads and process I/O; query text kept in memory only; attribution gaps labelled")

add(8,"Optional simplified main-window view with charts and top ten processes","App/SimpleDashboardView.swift; App/Views.swift; App/SettingsView.swift","TopProcessesTests; MemoriaUITests","Implemented","Persistent toolbar/Settings choice; full-view preferences retained; live UI acceptance pending")
add(8,"Top-ten summary ranks measured resources before limiting rows","Sources/MemoriaCore/TopProcesses.swift","TopProcessesTests","Implemented","Independent resource ranking; unavailable values excluded and measured zeros retained; verification pending")

add(8,"Configurable menu-bar readings and chart popover","App/MenuBarMonitor.swift; App/SettingsView.swift; App/MemoriaApp.swift","WidgetTests; interactive menu/window lifecycle","Implemented","CPU, memory, both and icon-only choices; preferences persist; live UI acceptance pending")
add(8,"Small and medium macOS WidgetKit extension","Widget/MemoriaWidget.swift; Memoria.xcodeproj; Configuration","Extension compiler/link checks; signed gallery acceptance","Implemented","Sandboxed aggregate-only extension; signed installation and runtime acceptance pending")
add(8,"Bounded private widget cache with explicit freshness and safe navigation","Sources/MemoriaWidgetSupport; App/WidgetPublisher.swift","WidgetTests","Implemented","Fixed-size aggregate schema, missing-value semantics, atomic storage, deletion, cadence and navigation-only URL checks")
add(9,"Verify signed widget gallery and shared App Group delivery","Documentation/Widgets.md; Configuration","Signed widget installation and lifecycle","Blocked externally","No configured signing identity; GUI launch unresolved")

add(8,"Original brain mark with light, dark and small-size bitmap exports","Branding; Scripts/build-icons.py; Scripts/export-icons.swift","ImageIO size/profile/alpha and ICNS round trips; visual proof","Implemented","Original image-generated artwork; 16–1024 px, 1x/2x and template exports")
add(8,"Brain identity in application, widget and menu bar","App/BrandMark.swift; App/Resources; Widget/MemoriaWidget.swift; Memoria.xcodeproj","Compiler, resource and bundle checks; live UI acceptance","Implemented","System-coloured alpha templates; default ICNS in development bundle")
add(8,"Layered Icon Composer source with default, dark and mono annotations","Branding/Memoria.icon; Scripts/generate-project.py","Native document build and appearance review","Implemented","Unmasked foreground and separate background; native decoding/rendering not verified")
add(9,"Verify native icon rendering and system appearance selection","Branding/README.md; Evidence/README.md","Icon Composer, Dock, Finder and dark/tinted/clear checks","Blocked externally","LaunchServices FileWrapper error on Apple's own template; asset compiler and GUI environment unresolved")

overrides=root/"Evidence/RequirementVerification.json"
if overrides.exists():
    updates=json.loads(overrides.read_text())
    for record in records:
        if record["requirement"] in updates: record.update(updates[record["requirement"]])

out=root/"Documentation"
out.mkdir(exist_ok=True)
data={"schema":1,"source":"User-supplied implementation plan","numberedBriefAvailable":False,"requirements":records}
(out/"Requirements.json").write_text(json.dumps(data,indent=2)+"\n")
lines=["# Requirements ledger","",
       "The supplied plan is the source of intent. The original numbered brief (sections 1–56) was not supplied; its wording is not reconstructed or claimed as audited. This ledger splits the supplied plan into individually reviewable entries and preserves its section-to-phase references.",
       "",
       "Status: Not started → Implemented → Verified, or Blocked externally / Unavailable on tested platform. Implemented means source exists, not that it compiled or ran. Each verification must name evidence and scope. An optional unavailable state can satisfy a fallback requirement without satisfying the measurement requirement.",
       "","## Numbered-brief traceability","","| Section | Plan phases |","|---|---|"]
for section in range(1,57):
    phases=[str(phase) for phase,sections in phase_sections.items() if section in sections]
    lines.append(f"| {section} | {', '.join(phases) or 'Not mapped by supplied plan'} |")
for phase in range(10):
    lines += ["",f"## Phase {phase}","","| ID | Requirement | Implementation | Tier | Tests | Evidence | Status |","|---|---|---|---|---|---|---|"]
    for r in records:
        if r["phase"]==phase:
            fields=[r["id"],r["requirement"],r["implementation"],str(r["tier"]),r["tests"],r["evidence"],r["status"]]
            lines.append("| "+" | ".join(v.replace("|","/") for v in fields)+" |")
(out/"Requirements.md").write_text("\n".join(lines)+"\n")
print(f"Wrote {len(records)} requirements; no runtime status inferred.")
