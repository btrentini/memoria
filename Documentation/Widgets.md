# Menu bar and desktop widgets

Memoria includes a menu-bar monitor and a separate WidgetKit extension for the desktop and Notification Centre. The menu bar uses the running app's telemetry; the desktop widget displays a saved, timestamped snapshot. This distinction follows [Apple's WidgetKit update model](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

## Using the menu bar

In Settings → General, enable **Show Memoria in the menu bar** and choose CPU, Memory, CPU and memory, or Icon only. The item appears in the macOS status area near the clock and other menu-bar items. macOS controls its position and available space.

Click the item for CPU and accounted-memory readings, a one-minute CPU chart, memory pressure and thermal state. Buttons open Memoria, Simple view, Quick Task Manager or widget setup. Closing the main window keeps the app running; quitting Memoria stops menu-bar monitoring. Readings follow the configured sampling policy, including slower background, low-power and thermal intervals. Opening the popover requests visible-view sampling.

CPU is a whole-machine percentage. Accounted memory is active + wired + compressed memory; it is not pressure or a claim about all available RAM. Missing readings display a dash, while measured zero remains zero. The compact menu label uses G for GiB. Preferences persist across launches.

## Adding a desktop widget

After installing a correctly signed build, open **Edit Widgets** on the desktop or in Notification Centre, search for Memoria and select the small or medium size. Enable **Share aggregate readings with desktop widgets** in Memoria's General settings and keep the app running to supply new readings. See [Apple's widget instructions](https://support.apple.com/en-au/guide/mac-help/mchl52be5da5/mac).

Both sizes display CPU and memory with a capture time. The medium widget also shows memory pressure and a short CPU chart ending at that capture time. Selecting the widget opens Overview; the medium CPU and memory areas link to their respective tabs. These links navigate only and cannot run process actions.

The publisher attempts an atomic cache update at most every 30 seconds. It requests a WidgetKit refresh at most every 15 minutes, with exceptions for initial state, sharing changes, sleep state and an explicit refresh. These are request limits, not a refresh guarantee: macOS controls rendering and scheduling. A timeline entry marks readings older than five minutes as **Last snapshot**; sleep produces **Paused** without readings. Older rendered content may remain until macOS refreshes it, including after quitting or disabling sharing. Capture times remain visible.

## Storage, isolation and signing

Only aggregate CPU, accounted/total memory, pressure, timestamps and up to 30 CPU history points are shared. There are no process names, PIDs, paths, arguments or network addresses. The fixed JSON file is limited to 32 KiB and lives at `MemoriaWidget/widget-summary-v1.json` in the App Group container. Reads and writes run on a serial utility queue with bounded admission; the publisher coalesces pending requests. Files use mode 0600 in a 0700 directory. Disabling sharing removes the file and requests a widget refresh. No data leaves the Mac.

The sandboxed extension links only `MemoriaWidgetSupport` and Apple frameworks. It does not enumerate processes, load the optional worker, contact the helper or collect telemetry itself. Unknown schema versions, oversized/corrupt files and invalid readings produce an unavailable state. An entitled application in the same App Group can access this cache; it is not a security boundary against other authorised members of that group.

Both targets use `$(TeamIdentifierPrefix)fyi.trentini.memoria.shared` in their App Group entitlements and `MemoriaAppGroup` Info value. Configure the same real team and matching signatures for the app and extension. The macOS identifier consists of the team prefix followed by the group name; see [Apple's App Group configuration](https://help.apple.com/xcode/mac/current/en.lproj/dev8dd3880fe.html) and [container access documentation](https://developer.apple.com/documentation/xcode/accessing-app-group-containers). No administrator helper or Endpoint Security entitlement is required for these widgets.

The development bundler embeds the extension but deliberately leaves App Group access unconfigured in an ad-hoc build. It cannot demonstrate gallery activation or shared-container access. The menu bar is independent of App Group signing. [Distribution](Distribution.md) records the remaining signed-installation gate.

## Verification

The shared model/store tests cover round trips, aggregate-only keys, zero versus absence, version/range/size validation, history bounds, clock changes, fixed-file permissions/replacement/deletion, symlink rejection, publication cadence, group identifiers, navigation-only links and menu formatting. Debug and optimised SDK-explicit compilation include the extension with application-extension restrictions. See `Evidence/WidgetVerification.json` for recorded outcomes and limits.

Interactive acceptance still needs a working GUI and signed installation: inspect both widget sizes in the gallery, confirm matching-container data delivery, exercise links with the main window closed, compare readings with capture times, disable sharing and verify deletion, test sleep/wake and stale data, and check light/dark appearance, reduced transparency, keyboard access, VoiceOver and crowded menu bars. Compilation and local policy tests do not establish those outcomes.
