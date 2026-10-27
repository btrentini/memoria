import Foundation

public enum SummaryStoreError:Error,Sendable {case tooLarge,invalid,notRegularFile,busy}
public enum WidgetGroup {
    public static let suffix=".fyi.trentini.memoria.shared"
    public static func validIdentifier(_ identifier:String) -> Bool {
        guard let matched=[suffix,".fyi.trentini.memoria.store.shared"].first(where:identifier.hasSuffix) else {return false}
        let team=identifier.dropLast(matched.count)
        return team.count==10 && team.allSatisfy {$0.isASCII && ($0.isUppercase || $0.isNumber)}
    }
    public static func directory(bundle:Bundle = .main) -> URL? {
        guard let identifier=bundle.object(forInfoDictionaryKey:"MemoriaAppGroup") as? String,validIdentifier(identifier),
              let root=FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:identifier) else {return nil}
        return root.appendingPathComponent("MemoriaWidget",isDirectory:true)
    }
}
/// Serial utility queue; fixed file name, bounded reads, atomic replacement.
public final class SummaryStore:Sendable {
    public static let filename="widget-summary-v1.json"
    private let admission=DispatchSemaphore(value:4)
    private let directory:URL
    private let queue=DispatchQueue(label:"fyi.trentini.memoria.widget-cache",qos:.utility)
    public init(directory:URL) {self.directory=directory}
    public func read() async throws -> WidgetSummary? {
        try await perform {
            let file=self.directory.appendingPathComponent(Self.filename)
            guard FileManager.default.fileExists(atPath:file.path) else {return nil}
            let attributes=try FileManager.default.attributesOfItem(atPath:file.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {throw SummaryStoreError.notRegularFile}
            guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= WidgetSummary.maxBytes else {throw SummaryStoreError.tooLarge}
            let handle=try FileHandle(forReadingFrom:file);defer {try? handle.close()}
            let data=try handle.read(upToCount:WidgetSummary.maxBytes+1) ?? Data()
            return try WidgetSummary.decode(data)
        }
    }
    public func write(_ summary:WidgetSummary) async throws {
        try await perform {
            let data=try summary.encoded()
            try FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let file=self.directory.appendingPathComponent(Self.filename)
            try data.write(to:file,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        }
    }
    public func remove() async throws {
        try await perform {
            let file=self.directory.appendingPathComponent(Self.filename)
            if FileManager.default.fileExists(atPath:file.path) {try FileManager.default.removeItem(at:file)}
        }
    }
    // A zero-timeout admission check never waits for a slot.
    private func reserve() -> Bool {admission.wait(timeout:.now()) == .success}
    private func perform<T:Sendable>(_ work:@escaping @Sendable () throws -> T) async throws -> T {
        try Task.checkCancellation()
        guard reserve() else {throw SummaryStoreError.busy}
        return try await withCheckedThrowingContinuation {continuation in
            queue.async {
                defer {self.admission.signal()}
                continuation.resume(with:Result {try work()})
            }
        }
    }
}
/// Limits disk writes and reload requests independently of telemetry sampling.
public struct SummaryPublicationPolicy:Sendable {
    private var lastAttempt:Double?
    private var lastReload:Double?
    private var lastState:String?
    public init() {}
    public mutating func shouldAttempt(now:Double,state:String,force:Bool=false) -> Bool {
        guard now.isFinite,now>=0 else {return false}
        let changed=lastState != state
        let elapsed=lastAttempt.map {now-$0}
        guard force || changed || elapsed == nil || elapsed!>=30 || elapsed!<0 else {return false}
        lastAttempt=now;lastState=state;return true
    }
    public mutating func shouldReload(now:Double,force:Bool=false) -> Bool {
        guard now.isFinite,now>=0 else {return false}
        let elapsed=lastReload.map {now-$0}
        guard force || elapsed == nil || elapsed!>=WidgetSummary.refreshAfter || elapsed!<0 else {return false}
        lastReload=now;return true
    }
}
