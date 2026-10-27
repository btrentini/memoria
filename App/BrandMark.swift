import SwiftUI

/// Original alpha-template artwork; the system supplies the foreground colour.
struct BrandMark:View {
    var size:CGFloat=18
    private var bundle:Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
    var body:some View {
        Image(size>18 ? "BrainMark":"BrainTemplate",bundle:bundle)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width:size,height:size).accessibilityHidden(true)
    }
}
