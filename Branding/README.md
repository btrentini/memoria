# Memoria identity

The revised mark has a recognisable brain outline, two scalloped hemispheres, broad cortical folds, a central fissure and a short stem. Cobalt blue connects the idea of memory with the app's monitoring role. The menu bar and widget use a separate simplified brain glyph so the folds remain legible at small sizes. No text, small circuitry or copied SF Symbol appears in the logo.

Open [Preview.png](Preview.png) to compare the exported appearances, small sizes and menu templates. This is an artwork proof, not a screenshot of a running app or Icon Composer.

## Files

| Asset | Use |
|---|---|
| [Memoria.icon](Memoria.icon) | Layered 1024 × 1024 macOS source, with background and foreground separated and default/dark/mono annotations |
| [Exports/Default-1024-Unmasked.png](Exports/Default-1024-Unmasked.png) | Default/light flattened artwork, sRGB |
| [Exports/Dark-1024-Unmasked.png](Exports/Dark-1024-Unmasked.png) | Matching dark flattened artwork, sRGB |
| [Exports/Mono-1024-Unmasked.png](Exports/Mono-1024-Unmasked.png) | Grayscale artwork, Gray Gamma 2.2 |
| [Exports/Logo-Cobalt-1024.png](Exports/Logo-Cobalt-1024.png) | Transparent flat brain mark, sRGB |
| Exports/PNG/Default, Dark, Mono | Conventional masked exports at 16, 32, 64, 128, 256, 512 and 1024 pixels |
| Exports/Memoria-Default.icns, Memoria-Dark.icns, Memoria-Mono.icns | Each contains ten standard/Retina representations |
| Exports/Memoria-Default.iconset, Memoria-Dark.iconset, Memoria-Mono.iconset | 16, 32, 128, 256 and 512 pt images, each at 1× and 2× |
| [LegacyAssets.xcassets](LegacyAssets.xcassets) | Optional conventional macOS AppIcon asset catalog; separate from the modern icon target |
| [Exports/MenuBar](Exports/MenuBar) | Black alpha templates at 16, 18, 24 and 32 pt, each at 1× and 2× |
| [Source/Generation.json](Source/Generation.json) | Generation provenance, revision instructions and master checksums |

The native palette uses cobalt `#365BE8`, porcelain `#ECF3FF`, midnight `#101B33` and ice blue `#A9C9FF`. The flattened artwork contains tonal shading; these are reference colours, not a claim that each pixel has a fixed colour.

## Apple conventions

The modern document uses an unmasked square canvas and a transparent PNG foreground. The background, appearance settings and material rendering are separate; no rounded enclosure or baked highlight is included in that foreground. Apple's renderer supplies the platform mask and effects. Apple supports 1024 × 1024 layered macOS artwork, default/dark/clear/tinted appearances, and sRGB, grayscale or Display P3 colour. See [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons).

Default, dark and mono are the native editing modes; clear and tinted renditions come from the system's mono rendering. The `.icon` source carries these annotations, but its live rendering remains unverified here. The flattened PNGs are separate authored fallbacks and marketing exports, not claimed pixel-identical renders of the layered document. Use the flat foreground in Icon Composer; do not import the already shaded fallback as a foreground layer. See [Icon Composer](https://developer.apple.com/icon-composer/) and [creating an icon](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

Conventional `.icns` files contain their own continuous rounded enclosure and transparent outer margin, because they are finished bitmap icons. Those files are not inputs to the modern renderer, which would mask them again. The `.icon` source is the direct edition’s primary Xcode app icon; the App Store target uses the conventional AppIcon asset catalog pending native renderer verification. The SDK-explicit development bundle uses the default `.icns`. The dark and mono `.icns` exports are alternatives for review or other tooling; macOS does not automatically switch arbitrary named `.icns` files. Apple's [archived high-resolution guidance](https://developer.apple.com/library/archive/documentation/General/Conceptual/MOSXAppProgrammingGuide/CommonAppBehaviors/CommonAppBehaviors.html) documents the conventional 1×/2× iconset sizes.

The menu bar uses the brain's alpha silhouette without an app-icon tile. SwiftUI template rendering supplies the system colour, including dark mode and selection. An 18 pt version avoids shrinking the padded app artwork into the status item; 16, 24 and 32 pt pairs cover smaller controls and larger in-app marks. All preserve transparency and use explicit point dimensions. AppKit NSImage representations have isTemplate enabled and explicit 1×/2× point sizes. These are raster assets, not resolution-independent SVGs; the checked-in masters and exports cover the target macOS sizes.

## Build and verification

From the repository root:

    python3 Scripts/build-icons.py
    python3 Scripts/generate-project.py

The first command uses the supplied PNG masters, CoreGraphics and ImageIO. It does not call an image-generation service or download anything. It exports and independently decodes all ten `.icns` representations, checking their size and pixel density. ImageIO is used directly because `iconutil` rejects even the correctly sized iconset in this session. The observed `iconutil` failure and the successful ImageIO round trip are retained in Evidence.

The Xcode app target references `Memoria.icon` and sets its App Icon name to Memoria. The app and widget resource phases copy the template images. The Swift package includes the app's resource bundle. The development bundler copies the default `.icns`, sets `CFBundleIconFile`, and includes the menu templates in both bundles before local signing.

The 16/32/64/128 px exports and both menu-template colours were visually reviewed in the proof sheet. PNG dimensions, colour profiles, alpha and `.icns` decoding are checked separately. App/extension compilation is separate from runtime appearance verification.

Icon Composer export currently fails before reading its document because Foundation's FileWrapper encounters LaunchServices `kLSDataUnavailableErr` (-10813); the same failure was reproduced with Apple's unmodified Xcode icon template. The normal asset compiler also encounters the previously recorded missing Xcode component. Native `.icon` decoding, material appearance, system-selected dark/tinted/clear modes and Dock/Finder behaviour therefore remain external verification gates. No Apple approval or completed runtime compliance check is claimed.

The original artwork was produced with the built-in image-generation tool and then exported deterministically to platform sizes and formats. The selected masters, revision instructions and previous prompt history are included. No Apple logo, SF Symbol artwork or private rendering implementation is shipped.

The menu template is an alpha mask: macOS supplies its colour and contrast for the menu-bar material and selection state. See [NSImage.isTemplate](https://developer.apple.com/documentation/appkit/nsimage/istemplate). The optional Dock icon uses the full-colour app artwork; the default background mode keeps the Dock entry hidden.
