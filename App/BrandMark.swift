import AppKit
import SwiftUI

/// Alpha templates let AppKit choose the correct menu, selection and contrast colour.
/// Explicit representations also work in the SDK-only development bundle.
struct BrandMark:View {
    var size:CGFloat=18
    private static var cache:[String:NSImage]=[:]
    private static var bundle:Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
    private var image:NSImage {
        let points=size<=16 ? 16:size<=18 ? 18:size<=24 ? 24:32
        let name=points==18 ? "BrainTemplate":points==32 ? "BrainMark":"BrainTemplate\(points)"
        if let cached=Self.cache[name] {return cached}
        let image=NSImage(size:NSSize(width:points,height:points))
        for suffix in ["","@2x"] {
            if let url=Self.bundle.url(forResource:name+suffix,withExtension:"png"),
               let data=try? Data(contentsOf:url),
               let representation=NSBitmapImageRep(data:data) {
                representation.size=NSSize(width:points,height:points)
                image.addRepresentation(representation)
            }
        }
        image.isTemplate=true
        Self.cache[name]=image
        return image
    }
    var body:some View {
        Image(nsImage:image).renderingMode(.template).resizable().scaledToFit()
            .frame(width:size,height:size).accessibilityHidden(true)
    }
}
