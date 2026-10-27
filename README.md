# How to use it as a user

**Memoria** is a native Mac performance monitor and process manager. It lives in the menu bar, beside the clock and other status icons, and shows CPU and memory readings without keeping an icon in the Dock.

![Memoria brain icon](Branding/Exports/PNG/Default/Memoria-128.png)

## Download and install

You need an **Apple Silicon Mac (M-series)** running **macOS 26 or later**. Intel Macs, Windows and Linux are not supported. You do not need Xcode, Python or a developer account to try the packaged app.

[Download the macOS preview](https://github.com/btrentini/memoria/releases/tag/v0.1.0-preview.1) and choose **Memoria-0.1.0-preview.1-macos-arm64.zip** under **Assets**. GitHub’s automatic “Source code” downloads are for developers and do not contain an installable application.

**This is an experimental preview.** It has an ad-hoc development signature, without an Apple Developer ID signature or notarisation. Full GUI and installation acceptance remain incomplete; [known issues](Documentation/KnownIssues.md) include launch failures observed in the development environment. There is no stable signed release or App Store listing yet.

1. Open the downloaded ZIP in Finder.
2. Drag **Memoria.app** from the extracted folder into **Applications**. You can also use an Applications folder in your home folder if you prefer a per-user installation.
3. Open Memoria from Applications. Look for the **brain icon in the menu bar**: the app starts quietly, with no main window or Dock icon by default.
4. Click the brain, then **Open Memoria** to see the dashboard.

If macOS blocks this unnotarised preview, follow [Apple’s app-specific approval instructions](https://support.apple.com/en-gb/102445) only if you trust the source: first try opening the app, then check **System Settings → Privacy & Security → Open Anyway**. This option may be unavailable on a managed Mac. Memoria does not require disabling Gatekeeper, removing quarantine attributes in Terminal, or changing security settings for other applications. If macOS reports that the app is damaged or contains malware, stop and [report the problem](https://github.com/btrentini/memoria/issues).

Each preview includes a plain-language installation file, a build manifest and **SHA256SUMS.txt**. Checksums help detect a damaged or changed download; they do not replace Apple signing or notarisation.

## Read your Mac’s activity

Use the sidebar to choose a resource. **Simple** view shows the main charts, readings and up to ten ranked processes. **Full** view adds detailed tables and an inspector. Choose a ranking metric, click a column heading to sort, and use search and filters to narrow the list. Selecting a process shows its available details.

The menu-bar popover gives you compact readings and access to **Quick Task Manager**. Its configurable shortcut is **Control–Shift–Escape**, subject to shortcut availability. Settings lets you choose which readings appear beside the brain.

For process management, try **Quit** first where it is available. **Terminate** requests termination; **Force Kill** requires confirmation and can discard unsaved work. Memoria does not automatically escalate termination to force killing. Process visibility and actions depend on macOS permissions. See [capabilities](Documentation/Capabilities.md) for measurement and permission limits.

## Background operation and startup

Closing the monitor keeps the menu-bar readings running. Choose **Quit Memoria** from its menu to stop the app.

In **Settings → General → Background and startup**, you can:

- Enable **Show Memoria in the Dock** if you prefer a Dock entry.
- Enable **Launch Memoria at login** after installing it in Applications. Approve it in **System Settings → General → Login Items** if macOS asks. This starts Memoria after you sign in, rather than before login.

Login startup is off until you enable it. It is deliberately unavailable in temporary build folders. The app reports registration failures and pending approval; a real login cycle has not yet passed acceptance. [Background behaviour and verification](Documentation/Background.md) explains the current scope.

## What is available in the preview?

| Capability | Current status |
|---|---|
| CPU, memory, process lists, network interfaces, volume, battery and thermal-pressure views | Implemented; readings depend on the Mac and permissions. Full acceptance is still in progress. |
| Ranked process tables, Simple/Full views and menu-bar readings | Included. Some GUI checks remain unresolved. |
| Desktop widgets | Source and extension included; signed App Group delivery and gallery activation are not verified. Do not expect widget sharing in the ad-hoc preview. |
| Administrator operations, experimental sensors and Endpoint Security | Disabled or unavailable pending signing, entitlements and validation. |
| App Store edition | A separate monitoring-only submission template, with no published listing. |

Missing or unsupported readings are labelled; they are not measured zero. There are no accounts, analytics, remote telemetry, automatic downloads or fan control. Optional recording and exports stay on your Mac unless you choose to share them.

## Update, remove or report a problem

To update, turn off launch at login, quit Memoria, replace the app in Applications with the newer download, and open it again. Re-enable launch at login if wanted. There is no automatic updater.

To remove Memoria, turn off launch at login, quit the app, remove any Memoria widgets and move Memoria.app to the Trash. Use the app’s recording/deletion controls first if you enabled local recording. Signed helper installations have a separate [removal procedure](Documentation/Distribution.md#helper-lifecycle); the preview does not enable the helper.

Report bugs in [GitHub Issues](https://github.com/btrentini/memoria/issues), including the app version, macOS version, chip family and steps to reproduce. Remove process lists, arguments, personal paths and other private information from logs or screenshots before posting. The [release notes](Documentation/ReleaseNotes-v.10.md) and [known issues](Documentation/KnownIssues.md) distinguish implemented features from verified behaviour.

# How to develop / contribute

Memoria uses **Swift 6, SwiftUI, AppKit and Swift Charts**, with a macOS 26 deployment target and ARM64 builds. Original code is [MIT licensed](LICENSE). The ordinary application has no third-party Swift package dependencies; Rust is optional and is not required for the build below.

## Set up and build

Use an Apple Silicon Mac with macOS 26 or later, **full Xcode 27.1 or later** with the macOS 27 SDK and Swift 6 compiler, **Python 3.9 or later**, and Git. These are the tested toolchain family and build target; newer toolchains still need verification. Open Xcode once, accept its licence and finish installing its components. Command Line Tools alone do not provide the complete test and application toolchain.

```sh
git clone https://github.com/btrentini/memoria.git
cd memoria
make doctor
make app
open build/Memoria.app
```

`make app` compiles the native modules, app, helper and widget, then assembles **build/Memoria.app** with its icons, libraries and a local ad-hoc signature. It does not install login items, register a helper, download dependencies or create a signed public release. Open the **.app bundle**, rather than the bare executable in Contents/MacOS, so resources and application identity are available.

The SDK build scripts honour `DEVELOPER_DIR`. Their default is `/Applications/Xcode.app/Contents/Developer`; if Xcode is installed elsewhere, set that variable before running Make. Use `make PYTHON=python3.12 app` if your Python executable has a different name. `make help` lists the available commands.

`make doctor` checks the compiler, SDK and required tools. It also checks Xcode project initialisation and reports that separately. The original test environment has a missing CoreSimulator framework, so the documented SDK build route was used there. A successful SDK build does not prove that Xcode project builds or the GUI work on that machine.

For normal Xcode development, open **Memoria.xcodeproj** and choose the shared **Memoria** scheme. Configure your own signing team for signed capabilities. The **MemoriaStore** scheme builds the separate sandboxed monitoring edition; it must not be confused with the full direct-distribution app. [Detailed build instructions](Documentation/Build.md) cover Swift Package Manager, Xcode and restricted compiler sessions.

## Test and package

```sh
make test
make verify-app
make preview-package
```

`make test` builds and runs the core/service tests and the separate Store/lifecycle tests. The current suite contains **65 tests**. It uses bounded disposable fixtures; it does not authorise testing destructive actions on everyday applications or another user’s processes. GUI, signed-helper, widget, sleep/resume and installation checks are separate parts of the [acceptance plan](Documentation/Acceptance.md).

`make verify-app` checks the bundle’s executable permissions, ARM64 binaries, local library dependencies, resources and signatures. `make preview-package` creates a Finder-installable preview ZIP, installation instructions, a source revision manifest and checksums in **build/distribution**. It refuses a dirty or stale source tree, so commit the intended changes and rebuild first. Packaging does not confer Developer ID signing or notarisation. The [distribution guide](Documentation/Distribution.md) describes the public-release gates.

To build the reduced App Store preview alone, use `make store-preview`. Its [submission template](AppStore/README.md) leaves the developer team, provisioning and listing details for later. No command uploads to Apple automatically.

## Contribute a change

Read [CONTRIBUTING.md](CONTRIBUTING.md), create a branch, make a focused change and run the checks appropriate to it. In a pull request, explain the behaviour changed, how it was tested and any remaining limitation. Keep real process captures, credentials, signing material and build products out of Git.

The [architecture](Documentation/Architecture.md), [capability matrix](Documentation/Capabilities.md), [requirements ledger](Documentation/Requirements.md) and [threat model](Documentation/ThreatModel.md) explain the boundaries between ordinary monitoring, process actions and optional privileged features. Dependency changes need a licence/provenance review and updated [audit and SBOM](Documentation/DependencyAudit.md). Asset changes should follow the [icon guidance](Branding/README.md).
