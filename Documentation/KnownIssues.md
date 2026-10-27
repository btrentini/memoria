# Known issues and release gates

This is a development source snapshot, not a production release.

1. Xcode project builds and XCUITest stop before compilation because the installed Xcode lacks CoreSimulator.framework. The first-launch installation request failed. SDK-explicit Swift/C builds are separate evidence.
2. The development app aborts inside macOS application registration before its views initialise. LaunchServices also returns -10827 despite the ARM64 executable being present and the assembled ad-hoc signature validating. The precise launch cause remains unresolved. Navigation, VoiceOver, shortcuts, resizing, notification delivery and window performance have not passed live acceptance.
3. This session denies both boot identity queries, swap inspection and local server binding. Process actions fail closed without boot identity. Native socket discovery has partial coverage; successful discovery of existing endpoints does not verify Free Port against a controlled listener.
4. The worker builds and its protocol/absence tests pass, but the native IOReport subscription is unavailable here. No GPU, power, temperature or fan measurement is validated. M2 Pro identity, Metal response and comparison with an independent reference remain unverified.
5. No valid Developer ID identity was available. Signed helper installation, real cross-user operations, revocation, upgrade/removal, notarisation, stapling and Gatekeeper acceptance remain blocked. The ad-hoc development bundle does not satisfy those gates.
6. Endpoint Security implementation and activation remain conditional on Apple-approved provisioning. The event abstraction and replay reconciliation do not establish live event collection.
7. No validated per-process GPU/network attribution or powermetrics adapter is exposed. Storage-driver counters are implemented, but controlled physical-device traffic comparisons remain outstanding.
8. Process/application membership uses observed bundle paths and inferred ancestry. It does not prove a signed bundle identity. Polling cannot reconstruct all brief processes, same-executable execs or already-reparented descendants.
9. The 5,000-row filter and simulated history tests pass. Monitoring CPU/energy budgets, warm-window latency, baseline footprint and an actual eight-hour soak remain unmeasured.
10. The menu-bar monitor and WidgetKit extension compile, and shared snapshot tests pass. Live menu-bar appearance, widget gallery activation, signed App Group data delivery and widget links remain unverified because GUI launch and signing are unresolved. Widget refreshes are controlled by macOS, so a widget may retain older content after a cache change or deletion. An earlier extension compile emitted a sandbox_apply diagnostic while still exiting successfully. Its origin was not isolated; The raw local diagnostic log is withheld from publication.

The requirements ledger contains the implementation and verification status for each supplied-plan item. An implemented source path is not a runtime pass.

The brain icon's bitmap exports and local bundle integration are supplied. Icon Composer export fails with a LaunchServices FileWrapper error even for Apple's unmodified icon template; native document decoding and live dark/tinted/clear/Dock/Finder appearance remain unverified. The conventional .icns fallback is encoded and decoded through Apple ImageIO. See [icon evidence](../Branding/README.md).

Background/login follow-up: local App Store quiet-launch, menu/window, settings and Dock-toggle checks passed. Subsequent UI automation returned AppleEvent timeout/handler errors, so complete acceptance of the final bundles remains open. Direct-edition live UI and a real login cycle are not claimed as verified. The exported icons, bundle resources, both SDK builds and 65 tests passed.
