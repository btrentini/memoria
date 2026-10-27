# Background monitoring and login startup

Memoria starts as a menu-bar app in both editions. It opens no monitor window and has no Dock entry by default. Click the brain beside the menu-bar readings, then choose **Open Memoria**. Closing a window keeps monitoring running; **Quit Memoria** stops it. Settings contains **Show Memoria in the Dock** for people who prefer a conventional Dock entry.

To start automatically, install a permanent copy in `/Applications`, open **Settings → Background and startup**, and enable **Launch Memoria at login**. Approve it in **System Settings → General → Login Items** if macOS requests approval. This starts Memoria after sign-in; it is not a service running before anyone logs in. Turn the same switch off to unregister the login item. Revocation in System Settings is respected and never silently reversed.

The application uses Apple’s [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp), [LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement) and accessory activation policy. Login registration is independent of the optional direct-edition privileged helper. It needs no administrator daemon, custom LaunchAgent file, scheduled shell command or stored credentials. Registration occurs only after the user enables the switch. Disabled, enabled, awaiting approval and unavailable states are shown separately; errors do not become a false success.

Temporary development bundles cannot register themselves. This prevents a login item pointing into a disposable build directory. The submission kit remains an unsigned-team preview; installing and enabling a permanent signed copy, logging out/in, and testing removal remain delivery checks. The workspace currently permits writes only in the old workspace and temporary directories, so this session does not install Memoria into Applications or change the Mac’s login registration.

The App Store preview has been observed launching with no windows, presenting its live menu popover, opening the monitor from the menu, and continuing to publish readings after the monitor closes.

Verification is recorded in [BackgroundVerification.json](../Evidence/BackgroundVerification.json). Unit tests use a fake service and do not alter real login settings. The shared lifecycle module is linked only into the application targets; the widget extension does not register login items or manage the Dock.
