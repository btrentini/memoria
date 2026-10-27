import Foundation
import Security
import MemoriaCore
import MemoriaCollectors
import MemoriaNative

public struct ProcessDetails:Sendable {
    public let identity:ProcessIdentity
    public let executable:ExecutableIdentity
    public let signing:String
    public let files:[String]
    public let fileCoverage:String
}

/// Short-lived, bounded cache. Revalidation happens even when a cache entry exists.
public actor ProcessDetailStore {
    private struct Entry {let value:ProcessDetails;let collected:Double}
    private var cache:[ProcessIdentity:Entry]=[:]
    private let executor=NativeExecutor()
    public init() {}
    public func inspect(_ selected:ProcessSnapshot) async throws -> ProcessDetails {
        let cached=cache[selected.identity]
        let result=try await executor.run {
            let reader=NativeReader(),live=try NativeReader().process(selected.identity.pid)
            guard live.identity == selected.identity,let executable=live.executable,executable == selected.executable else {throw InspectionError.identityChanged}
            if let cached,cached.value.executable == executable,ProcessInfo.processInfo.systemUptime-cached.collected<5 {return cached.value}
            var code:SecStaticCode?
            var signing="Unavailable"
            let create=SecStaticCodeCreateWithPath(URL(fileURLWithPath:executable.path) as CFURL,[],&code)
            if create == errSecSuccess,let code {
                var info:CFDictionary?
                let status=SecCodeCopySigningInformation(code,SecCSFlags(rawValue:kSecCSSigningInformation),&info)
                if status == errSecSuccess,let data=info as? [String:Any] {
                    let identifier=data[kSecCodeInfoIdentifier as String] as? String ?? "Unknown identifier"
                    let team=data[kSecCodeInfoTeamIdentifier as String] as? String ?? "No team identifier"
                    // Metadata is not a claim about SIP, safety, or running-code integrity.
                    signing="On-disk signing metadata: \(identifier) · \(team)"
                } else {signing="Signing metadata unavailable (OSStatus \(status))"}
            } else {signing="Signing metadata unavailable (OSStatus \(create))"}
            var raw=[mm_file](repeating:mm_file(),count:256),denied:Int32=0,truncated:Int32=0
            let count=mm_open_files(live.identity.pid,&raw,Int32(raw.count),&denied,&truncated)
            let files=count>0 ? raw.prefix(Int(count)).map {item in
                withUnsafeBytes(of:item.path) {bytes in String(decoding:bytes.prefix(while:{$0 != 0}),as:UTF8.self)}
            }:[]
            let after=try reader.process(selected.identity.pid)
            guard after.identity == live.identity,after.executable == executable else {throw InspectionError.identityChanged}
            let coverage=count<0 ? "File inspection unavailable (errno \(-count))":"\(files.count) visible file paths; \(denied) inaccessible descriptors\(truncated != 0 ? "; scan limit reached":""). Paths are an instantaneous snapshot."
            return ProcessDetails(identity:live.identity,executable:executable,signing:signing,files:files,fileCoverage:coverage)
        }
        cache[selected.identity]=Entry(value:result,collected:ProcessInfo.processInfo.systemUptime)
        if cache.count>32 {cache=cache.filter {ProcessInfo.processInfo.systemUptime-$0.value.collected<5};if cache.count>32 {cache=[selected.identity:cache[selected.identity]!]} }
        return result
    }
}
