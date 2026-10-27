import Foundation
import MemoriaCore
import MemoriaCollectors

public actor RecordingStore {
    private let executor=NativeExecutor()
    public let directory:URL
    public let quota:Int
    public let retentionDays:Int
    public init(directory:URL,quota:Int=25*1024*1024,retentionDays:Int=7) {self.directory=directory;self.quota=max(1024,quota);self.retentionDays=max(1,retentionDays)}
    public func append(_ samples:[MetricSample]) async throws {
        let directory=self.directory,quota=self.quota,retention=self.retentionDays
        // Only aggregate numeric metrics. Arguments, paths and process metadata never enter routine recording.
        let permitted=samples.filter {$0.value?.double != nil || $0.value == nil}
        try await executor.run {
            let fm=FileManager.default;try fm.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let date=ISO8601DateFormatter().string(from:.now).prefix(10)
            let file=directory.appendingPathComponent("\(date).jsonl")
            let data=try JSONEncoder().encode(permitted)+Data([10])
            guard data.count <= quota else {throw InspectionError.unavailable("Recording batch exceeds quota")}
            if !fm.fileExists(atPath:file.path) {fm.createFile(atPath:file.path,contents:Data(),attributes:[.posixPermissions:0o600])}
            let handle=try FileHandle(forWritingTo:file);defer {try? handle.close()}
            try handle.seekToEnd();try handle.write(contentsOf:data)
            let files=try fm.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.fileSizeKey,.contentModificationDateKey]).filter {$0.pathExtension == "jsonl"}.sorted {$0.lastPathComponent < $1.lastPathComponent}
            var total=try files.reduce(0) {$0+(try $1.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)}
            let cutoff=Date.now.addingTimeInterval(-Double(retention)*86400)
            for url in files {
                let values=try url.resourceValues(forKeys:[.fileSizeKey,.contentModificationDateKey]),size=values.fileSize ?? 0
                if total > quota || (values.contentModificationDate ?? .distantPast) < cutoff {try fm.removeItem(at:url);total -= size}
            }
        }
    }
    public func deleteAll() async throws {
        let directory=self.directory
        try await executor.run {
            guard FileManager.default.fileExists(atPath:directory.path) else {return}
            for url in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil) where url.pathExtension == "jsonl" {try FileManager.default.removeItem(at:url)}
        }
    }
    public static func recover(_ data:Data) -> (samples:[[MetricSample]], corruptLines:Int) {
        var samples:[[MetricSample]]=[],corrupt=0
        for line in data.split(separator:10) {
            if line.count <= 1_048_576,let batch=try? JSONDecoder().decode([MetricSample].self,from:Data(line)) {samples.append(batch)} else {corrupt += 1}
        }
        return (samples,corrupt)
    }
}
