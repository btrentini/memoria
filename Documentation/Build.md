# Build and verification

The project targets ARM64 macOS 26.0 and Swift 6 language mode. The inspected installation reported Xcode 27.1 (27A9275), SDK 27.0, Swift 6.4 and macOS 26.7.1 (25G241). Hardware-model discovery was denied in this execution context. M2 Pro compatibility is not inferred from architecture or SDK.

The stable application has no third-party Swift dependencies:

    swift build
    swift test
    swift build -c release
    swift run MemoriaProbe

The checked-in Xcode project uses local package libraries:

    xcodebuild -project Memoria.xcodeproj -scheme Memoria -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
    xcodebuild -project Memoria.xcodeproj -scheme Memoria -configuration Release -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
    xcodebuild -project Memoria.xcodeproj -scheme Memoria -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test

The Memoria scheme includes the MemoriaWidget extension through a target dependency and embeds it in Contents/PlugIns. Its only local library is MemoriaWidgetSupport, a Foundation-only aggregate schema/store module. Swift Package Manager builds that module and the ordinary app; the widget target is defined in Xcode. The SDK-explicit fallback also compiles and links the widget, with application-extension restrictions for both the extension and its support library. Installation in the widget gallery is a separate signed-build check.

The app target uses Branding/Memoria.icon as its modern app icon. The app and widget share template-image resources. The SDK-explicit bundle uses the checked-in default .icns fallback; regenerate size/format exports with `python3 Scripts/build-icons.py`. That command uses local masters and Apple ImageIO, not an image-generation API. See [branding and icon verification](../Branding/README.md) for appearance variants and the blocked native Icon Composer check.

Scripts/generate-project.py deterministically regenerates the project and schemes using Python's standard library. Scripts/direct-build.py is an SDK-explicit development fallback. It does not repair Xcode, install components, sign a release or prove runtime correctness.

The initial Xcode build failed before compiling application code because CoreSimulator.framework was absent from /Library/Developer/PrivateFrameworks. Xcode recommended xcodebuild -runFirstLaunch; that attempt failed to create an install request. This machine-level problem must be resolved before claiming an Xcode build pass.

## Tests and fixtures

Swift Testing covers accounting/reset rules, absence, history retention/export/recovery, port formats, grouping, event reconciliation, process identity/exec races, signal/exit distinction, denial, helper policy/replay, worker framing/ranges and bounded subprocesses. The 5,000-row filter benchmark prints p95 duration. A simulated eight-hour history test checks bounds; it is not an eight-hour runtime soak.

MemoriaFixture provides bounded CPU, memory, ignored-SIGTERM, IPv4/IPv6 listener and UDP workloads. It is a separate target, never launched by the app. Its default lifetime is ten seconds and maximum is 120 seconds. MemoriaProbe exercises native providers without the GUI.

XCUITest exercises navigation, search and Quick Task Manager. Its existence does not establish VoiceOver, shortcut conflicts, reduced motion/transparency, resizing or warm-presentation performance; those require recorded verification.

## Optional worker

The build script requires Rust 1.95.0 and does not install a compiler. The separate worker is pinned to macmon commit 39e98aa73e49256e6281b2a228f6ef3499ae3209 with application features disabled. Consult the dependency audit and lockfile status before running:

    sh Scripts/build-worker.sh

The GUI requires a signed worker at its auxiliary-executable path and explicit opt-in. Stable development builds work without it. Dependency retrieval, lock resolution and advisory coverage remain distinct gates.

## SDK-explicit verification in restricted sessions

    MEMORIA_NESTED_SANDBOX=1 MEMORIA_CONFIGURATION=Release python3 Scripts/direct-build.py
    MEMORIA_NESTED_SANDBOX=1 python3 Scripts/direct-tests.py
    sh Scripts/native-tests.sh
    python3 Scripts/bundle-development.py

MEMORIA_NESTED_SANDBOX=1 selects the Swift compiler's supported option to avoid nesting its macro subprocess sandbox inside the existing session sandbox. The session's filesystem/network restrictions still apply. The default leaves this option off. Only the Apple-provided compiler macros and local test macros are involved.

The fallback writes build/direct. MEMORIA_BUILD_FROM can resume a module after a compiler error; a clean final build must be recorded separately. Release enables optimisation and whole-module optimisation; performance budgets must identify configuration.

## Source publication

The Git repository contains source, artwork, pinned worker dependencies and sanitised verification summaries. Build products, runtime captures and raw diagnostic logs are excluded. Build locally from a clean checkout; the commit identifies the published source snapshot. `python3 Scripts/package-source.py` archives the committed tree only.

The SDK-explicit fallback compiles each module with one compiler frontend to avoid repeated framework imports. `MEMORIA_MODULE_CACHE` selects a reusable cache for the build and test scripts. This changes compilation scheduling, not application sandbox settings.
