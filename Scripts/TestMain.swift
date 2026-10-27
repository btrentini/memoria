import Foundation
import Testing

@main struct MemoriaTestRunner {
    static func main() async {
        let status:Int32 = await Testing.__swiftPMEntryPoint()
        exit(status)
    }
}
