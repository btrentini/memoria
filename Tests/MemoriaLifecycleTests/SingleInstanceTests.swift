import Foundation
import Testing
import MemoriaLifecycle

@Suite("Single-instance ownership") struct SingleInstanceTests {
    private func directory() throws -> URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("memoria-instance-test-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        return url
    }
    @Test func exclusiveUntilReleasedAndContainsNoProcessData() throws {
        let root=try directory();defer {try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("instance.lock")
        var first=try SingleInstanceLease.acquire(at:file)
        #expect(first != nil)
        #expect(try SingleInstanceLease.acquire(at:file) == nil)
        #expect(try Data(contentsOf:file).isEmpty)
        let inode=try FileManager.default.attributesOfItem(atPath:file.path)[.systemFileNumber] as? NSNumber
        first=nil
        let replacement=try SingleInstanceLease.acquire(at:file)
        #expect(replacement != nil)
        #expect(try FileManager.default.attributesOfItem(atPath:file.path)[.systemFileNumber] as? NSNumber == inode)
        withExtendedLifetime(replacement) {}
    }
    @Test func separateEditionsHaveIndependentLocks() throws {
        let root=try directory();defer {try? FileManager.default.removeItem(at:root)}
        let direct=try SingleInstanceLease.acquire(at:root.appendingPathComponent("direct.lock"))
        let store=try SingleInstanceLease.acquire(at:root.appendingPathComponent("store.lock"))
        #expect(direct != nil && store != nil)
        withExtendedLifetime((direct,store)) {}
    }
    @Test func refusesSymlinkWithoutChangingDestination() throws {
        let root=try directory();defer {try? FileManager.default.removeItem(at:root)}
        let target=root.appendingPathComponent("keep.txt"),link=root.appendingPathComponent("instance.lock")
        try Data("keep".utf8).write(to:target)
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:target)
        #expect(throws:(any Error).self) {try SingleInstanceLease.acquire(at:link)}
        #expect(try Data(contentsOf:target) == Data("keep".utf8))
    }
    @Test func refusesSharedPermissionsAndDirectories() throws {
        let root=try directory();defer {try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("instance.lock")
        try Data().write(to:file)
        try FileManager.default.setAttributes([.posixPermissions:0o644],ofItemAtPath:file.path)
        #expect(throws:(any Error).self) {try SingleInstanceLease.acquire(at:file)}
        #expect(throws:(any Error).self) {try SingleInstanceLease.acquire(at:root)}
    }
    @Test func refusesHardLinkedFiles() throws {
        let root=try directory();defer {try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("original.lock"),link=root.appendingPathComponent("instance.lock")
        try Data().write(to:file)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        try FileManager.default.linkItem(at:file,to:link)
        #expect(throws:(any Error).self) {try SingleInstanceLease.acquire(at:link)}
    }
}
