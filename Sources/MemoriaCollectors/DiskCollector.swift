import Foundation
import IOKit

public struct DiskSnapshot: Codable, Sendable, Identifiable {
    public let id: UInt64
    public let name: String
    public let readBytes, writtenBytes: UInt64?
    public var readRate, writeRate: Double?
}

/// Keys documented in the SDK's IOKit/storage/IOBlockStorageDriver.h.
/// Each registry service is reported separately; no APFS-volume summation.
public enum DiskCollector {
    public static func read() -> [DiskSnapshot] {
        var iterator:io_iterator_t=0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching("IOBlockStorageDriver"),&iterator)==KERN_SUCCESS else {return []}
        defer {IOObjectRelease(iterator)}
        var result:[DiskSnapshot]=[]
        while result.count<64 {
            let service=IOIteratorNext(iterator)
            guard service != 0 else {break}
            defer {IOObjectRelease(service)}
            var identifier:UInt64=0
            guard IORegistryEntryGetRegistryEntryID(service,&identifier)==KERN_SUCCESS else {continue}
            var name=[CChar](repeating:0,count:128)
            _=IORegistryEntryGetName(service,&name)
            let label=String(decoding:name.prefix(while:{$0 != 0}).map{UInt8(bitPattern:$0)},as:UTF8.self)
            let statistics=IORegistryEntryCreateCFProperty(service,"Statistics" as CFString,kCFAllocatorDefault,0)?.takeRetainedValue() as? [String:Any]
            func counter(_ key:String) -> UInt64? {
                guard let value=statistics?[key] as? NSNumber,value.doubleValue.isFinite,value.doubleValue>=0 else {return nil}
                return value.uint64Value
            }
            result.append(DiskSnapshot(id:identifier,name:label,readBytes:counter("Bytes (Read)"),writtenBytes:counter("Bytes (Write)")))
        }
        return result
    }
}
