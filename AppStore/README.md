# Memoria — App Store submission template

This kit prepares a separate, sandboxed monitoring edition for a future Mac App Store submission. It includes source, a local preview, listing drafts, privacy/support pages and Xcode archive/export commands. **It is not an upload-ready App Store package.** No developer team, signing identities, provisioning profiles, review contact or hosted URLs are configured, and nothing has been uploaded to Apple.

The current store build is **1.0.0 (1)** with bundle ID `fyi.trentini.memoria.store` and widget ID `fyi.trentini.memoria.store.widget`. These are proposed identifiers; register them under your own team before upload. The display name is Memoria; the separate product filename is `MemoriaStore.app`. The direct edition retains its original target and identifiers.

## Contents and scope

The App Store edition contains CPU and memory charts, memory accounting and pressure, per-interface traffic, battery information where available, thermal state, a menu-bar monitor and opt-in desktop widgets. It links only the first-party `MemoriaStoreMetrics` and `MemoriaWidgetSupport` modules. The C collector uses public Mach statistics and interface counters; the Swift collector uses public power-source APIs and thermal state. It does not link the direct edition's collectors, services, helper or Rust dependencies.

Process resource lists/actions, Free Port, administrator operations, Endpoint Security and private sensor telemetry are excluded from this edition. This implements the reduced App Store option described in the original plan; the full process manager remains the separate direct-distribution edition. Apple requires sandboxing and prohibits root escalation and private APIs in store apps. [App Review Guidelines, 2.4.5 and 2.5.1](https://developer.apple.com/app-store/review/guidelines/)

## Complete these details later

Edit `Submission.json` and the drafts in `Metadata/en-GB/`:

- Register the application and widget bundle IDs and the App Group `<TeamIdentifierPrefix>fyi.trentini.memoria.store.shared`. Xcode expands the prefix from the actual provisioning configuration; do not insert a fake team.
- Configure your real Apple Developer team, signing certificates and provisioning profiles in Xcode. Use App Store distribution signing, including Mac Installer Distribution for the installer export; Developer ID is a different distribution route. [Apple certificate roles](https://developer.apple.com/help/account/certificates/certificates-overview/)
- Create the macOS app record in App Store Connect. Confirm the name, SKU, category, price, territories, release mode and review contact. Increment the Mac build number for each new uploaded build.
- Host `Site/privacy.html` and `Site/support.html` on public HTTPS URLs you control. Review the wording and links, then fill those URLs in `Submission.json` and App Store Connect. These drafts have not been deployed.
- Confirm the privacy questionnaire against the final app and your actual practices. The proposed answer is “Data Not Collected”: readings stay on-device, with no analytics or remote telemetry. The website/support provider's handling of voluntarily submitted information is described separately. [Apple privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- Complete the current age-rating and encryption questionnaires. Confirm the proposed no-content/no-non-exempt-encryption answers; no legal or account declaration has been submitted on your behalf.
- Capture real screenshots after the signed app passes acceptance. `Screenshots/README.md` gives the accepted Mac sizes and a capture plan. One real local overview capture is included for reference; reconfirm it against the signed build. No artwork proof or fabricated telemetry is presented as an app screenshot.

## Build now

From the source root, using the installed SDK and Python 3:

```sh
python3 Scripts/check-app-store.py
python3 Scripts/build-app-store-preview.py
python3 Scripts/test-app-store.py
python3 Scripts/check-app-store.py --bundle build/store-preview/MemoriaStore.app
```

In a nested execution sandbox, the documented `MEMORIA_NESTED_SANDBOX=1` compiler option may be needed. It does not grant filesystem, network or App Sandbox permissions. The preview statically links its first-party modules and uses an ad-hoc signature with App Sandbox and Hardened Runtime. It has no App Group access and cannot be uploaded to App Store Connect.

The current installation reports Xcode 27.1, SDK 27.0 and Swift 6.4. SDK-explicit compilation succeeds, but `xcodebuild -list` still fails loading `CoreSimulator.framework`. Repair Xcode's installation/first-launch components before the archive step. A successful `xcodebuild -version` alone does not prove the archive tools work. The SDK-built sandboxed preview now launches after its first-party modules were linked statically; this does not establish full signed acceptance.

## Archive and export later

Use the shared **MemoriaStore** scheme, not the direct **Memoria** scheme. The scripts deliberately have no upload action.

```sh
python3 Scripts/app-store.py archive --team YOUR_TEAM_ID --version 1.0.0 --build 1
python3 Scripts/app-store.py export --team YOUR_TEAM_ID --version 1.0.0 --build 1
```

`YOUR_TEAM_ID` is a placeholder and the script rejects it. Replace it with your real ten-character Team ID. Add `--allow-provisioning-updates` only when you want Xcode to contact your already configured developer account. Do not put passwords, private keys, API keys or exported certificates in this repository or kit.

The archive is created by Xcode under `build/app-store/`; export uses the `app-store-connect` method with `destination=export`. It does not relabel the local preview as an archive. Xcode must produce and validate the correctly signed installer package before upload. App Store submission is separate from Developer ID notarisation. [Apple packaging workflow](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution), [upload workflow](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)

## Acceptance before submission

Record the actual signing team, build, OS and hardware in private release evidence. Verify live launch, all six views, Simple mode, pause/resume, menu-bar lifetime, keyboard/VoiceOver use, light/dark appearance, CPU/memory behaviour, sleep/rebaseline, and long-run resource bounds. Verify widget gallery installation, App Group entitlement matching, route opening and cache deletion on opt-out. Test on a clean Mac without development tooling. Check the final binary for prohibited components and review both privacy manifests.

The preparation results are in `Validation.json`; the [store preparation ledger](../Documentation/AppStoreRequirements.md) tracks the remaining work. Compilation, local signatures and automated tests do not establish signed sandbox behaviour, App Review approval or store availability. Complete the live checks, provide real screenshots and working URLs, then validate through Xcode Organizer/App Store Connect before submitting for review. Prefer manual release for the first version.

To rebuild the preparation ZIP after updating the validation record, run `python3 Scripts/package-app-store-template.py`. The output is a template ZIP, not the signed installer package required by App Store Connect. Use `python3 Scripts/check-app-store.py --bundle PATH_TO_EXPORTED_APP --distribution` to require App Store certificates and provisioned group entitlements on a future signed export.
