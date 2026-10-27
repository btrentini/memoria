# Direct distribution and release gates

Developer ID distribution is the intended route. A development build, ad-hoc signature and successful compile do not establish notarisation or Gatekeeper acceptance.

Configure a real signing team and Developer ID Application identity. Sign nested executables/frameworks before the app, with Hardened Runtime. Exact identifiers are fyi.trentini.memoria, fyi.trentini.memoria.helper and fyi.trentini.memoria.worker. Embed the configured team under MemoriaSigningTeam in app/helper Info dictionaries. Missing configuration disables these capabilities.

The widget identifier is fyi.trentini.memoria.widget. Sign its nested libraries, then Contents/PlugIns/MemoriaWidget.appex, before signing the enclosing app. Use Configuration/MemoriaWidget.entitlements for the sandboxed extension and Configuration/Memoria.entitlements for the app. Both must resolve the same real TeamIdentifierPrefix and App Group, with matching MemoriaAppGroup Info values. The Xcode project carries these settings and embeds the extension with CodeSignOnCopy; no permissive group fallback is shipped. Verify each nested signature and the expanded entitlements before testing the gallery and shared-container delivery. The ad-hoc bundler deliberately omits App Group access; see [widget setup and acceptance](Widgets.md).

Before archiving, complete the native/worker/helper gates, pin included dependencies, regenerate SBOM/notices, and record source revision and machine. Package the signed app, submit with notarytool using a local Keychain profile, staple the ticket, and verify using codesign, spctl and a clean installation on a separate account/system.

No valid signing identity was visible initially. Signing, notarisation, stapling, external Gatekeeper behaviour, upgrade and uninstall remain unverified.

## Experimental GitHub preview

A preview can be shared before Developer ID credentials exist, provided its limitations remain explicit. From a clean committed checkout:

    MEMORIA_CONFIGURATION=Release make app test
    make preview-package

`build/distribution` contains the versioned ZIP, manifest and SHA256SUMS.txt. The package uses an ad-hoc development signature; it is not notarised or production-ready. The script checks build provenance, archive integrity and executable permissions after extraction. It never uploads or changes Gatekeeper settings.

Publish these three files as assets of a GitHub **pre-release**, tied to the exact source commit in the manifest. The release description must name the tested configuration and outstanding GUI, installation and signed-capability gates. Link users to the release assets, not GitHub’s automatic source archives. Keep build products out of Git.

The package includes Finder installation, update and removal instructions. Users may need Apple’s app-specific approval flow; managed systems can disallow it. A regular signed download remains a separate release gate.

## Helper lifecycle

Registration is only available from Settings. macOS may require approval in System Settings. Registration does not confer a standing right to terminate processes: every request has a separately authorised target. Removal is available from Settings and should precede deleting the installed app. Signed installation, denied/revoked approval, interrupted XPC, upgrade mismatch and removal need isolated testing.

## Endpoint Security

Polling reconciliation works independently of ES. A system-extension target is conditional on Apple-approved provisioning. Adding an entitlement to an ordinary build does not establish live support. Activation, gaps, removal and TCC behaviour need verification after approval.

## App Store assessment

A reduced edition could retain public host metrics, restricted process views, history and menus. The private-API worker, broad inspection and daemon require separate feasibility and App Review assessment. No App Store approval is claimed.

[Apple notarisation documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) is the distribution reference.

## Commands for a credentialled release environment

Use a configured Developer ID build, not the fallback ad-hoc bundle. Keep signing identities and notary credentials in the local Keychain. After completing the release gates, the expected sequence is:

    xcodebuild -project Memoria.xcodeproj -scheme Memoria -configuration Release -archivePath build/Memoria.xcarchive DEVELOPMENT_TEAM=YOURTEAMID archive
    codesign --verify --strict --verbose=2 build/Memoria.xcarchive/Products/Applications/Memoria.app
    ditto -c -k --keepParent build/Memoria.xcarchive/Products/Applications/Memoria.app build/Memoria-notary.zip
    xcrun notarytool submit build/Memoria-notary.zip --keychain-profile MemoriaNotary --wait
    xcrun stapler staple build/Memoria.xcarchive/Products/Applications/Memoria.app
    xcrun stapler validate build/Memoria.xcarchive/Products/Applications/Memoria.app
    spctl --assess --type execute --verbose=4 build/Memoria.xcarchive/Products/Applications/Memoria.app

Choose Developer ID Application signing explicitly in the archive/export configuration. If including the optional worker, copy it into Contents/MacOS, sign it with identifier fyi.trentini.memoria.worker and Hardened Runtime before signing the enclosing app, and repeat nested-code verification. Repackage after stapling; the pre-staple submission ZIP is not the final delivery artefact. These commands have not been executed against a credentialled build here.

Helper cancellation stops work that has not yet been signalled and stops further observation; it cannot undo a delivered signal. Protocol mismatch prevents upgrade-incompatible requests. The helper keeps at most 128 in-memory audit entries containing request UUID, time, action and outcome, without arguments, paths, names or authorisation forms. Signed lifecycle and revocation tests remain mandatory.
