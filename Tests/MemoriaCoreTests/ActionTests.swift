import Foundation
import Darwin
import Testing
import MemoriaCore
import MemoriaCollectors
@testable import MemoriaServices

actor FakeBackend:ProcessActionBackend {
    var current:ProcessSnapshot?
    var signalError:Int32=0
    var exits=true
    var signals:[Int32]=[]
    init(_ current:ProcessSnapshot?,error:Int32=0,exits:Bool=true) {self.current=current;self.signalError=error;self.exits=exits}
    func inspect(_ pid:Int32) throws -> ProcessSnapshot {guard let current else {throw InspectionError.system(ESRCH)};return current}
    func signal(_ pid:Int32,number:Int32) -> Int32 {signals.append(number);if signalError == 0 && exits {current=nil};return signalError}
}
@Suite("Termination safety") struct ActionTests {
    @Test func staleIdentityNeverSignalled() async throws {
        let original=specimen(),backend=FakeBackend(specimen(start:101)),target=try #require(TerminationTarget(process:original))
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.forceKill,confirmed:true),observationSeconds:0)
        #expect(result.first?.status == .identityChanged);#expect(await backend.signals.isEmpty)
    }
    @Test func executableChangeNeverSignalled() async throws {
        let backend=FakeBackend(specimen(path:"/bin/new")),target=try #require(TerminationTarget(process:specimen()))
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.terminate,confirmed:true))
        #expect(result.first?.status == .identityChanged);#expect(await backend.signals.isEmpty)
    }
    @Test func signalSuccessNeedsExitObservation() async throws {
        let backend=FakeBackend(specimen(),exits:false),target=try #require(TerminationTarget(process:specimen()))
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.terminate,confirmed:true),observationSeconds:0)
        #expect(result.first?.status == .stillRunning);#expect(await backend.signals == [SIGTERM])
    }
    @Test func exitObserved() async throws {
        let backend=FakeBackend(specimen()),target=try #require(TerminationTarget(process:specimen()))
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.forceKill,confirmed:true))
        #expect(result.first?.status == .exitObserved);#expect(await backend.signals == [SIGKILL])
    }
    @Test func deniedPreservesErrno() async throws {
        let backend=FakeBackend(specimen(),error:EPERM),target=try #require(TerminationTarget(process:specimen()))
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.terminate,confirmed:true))
        #expect(result.first?.status == .denied);#expect(result.first?.errorNumber == EPERM)
    }
    @Test func alreadyExited() async throws {
        let backend=FakeBackend(nil),target=try #require(TerminationTarget(process:specimen()))
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.terminate,confirmed:true))
        #expect(result.first?.status == .alreadyExited);#expect(await backend.signals.isEmpty)
    }
    @Test func invalidAndUnconfirmedScopes() throws {
        let target=try #require(TerminationTarget(process:specimen()))
        let now=ProcessInfo.processInfo.systemUptime
        #expect(ActionPolicy.rejection(for:TerminationRequest(targets:[target],action:.forceKill,confirmed:false),now:now,excludedPIDs:[]) != nil)
        #expect(ActionPolicy.rejection(for:TerminationRequest(targets:[target],action:.terminate,confirmed:true,createdMonotonic:now-31),now:now,excludedPIDs:[]) != nil)
        #expect(ActionPolicy.rejection(for:TerminationRequest(targets:[target],action:.terminate,confirmed:true,createdMonotonic:now),now:now,excludedPIDs:[42]) != nil)
        #expect(TerminationTarget(process:specimen(pid:0)) == nil);#expect(TerminationTarget(process:specimen(pid:1)) == nil)
        #expect(ActionPolicy.command(for:target,action:.forceKill) == "/bin/kill -KILL 42")
    }
    @Test func helperRejectsReplayMalformedAndWrongTeam() throws {
        let target=try #require(TerminationTarget(process:specimen())),now=ProcessInfo.processInfo.systemUptime
        let envelope=HelperEnvelope(request:TerminationRequest(targets:[target],action:.terminate,confirmed:true,createdMonotonic:now))
        var policy=HelperReplayPolicy()
        #expect(policy.accept(envelope,now:now,excluded:[]) == nil)
        #expect(policy.accept(envelope,now:now,excluded:[]) != nil)
        #expect(HelperConfiguration.requirement(identifier:"attacker",team:"ABCDEFGHIJ") == nil)
        #expect(HelperConfiguration.requirement(identifier:HelperConfiguration.appIdentifier,team:"\" or true") == nil)
        #expect(!AdministratorAuthorization.validate(Data()))
    }
    @Test func commandTimeoutAndBoundedOutput() async throws {
        let runner=BoundedCommand()
        let timeout=try await runner.run(executable:URL(fileURLWithPath:"/bin/sleep"),arguments:["2"],timeout:0.1)
        #expect(timeout.timedOut)
        let flood=try await runner.run(executable:URL(fileURLWithPath:"/usr/bin/yes"),arguments:[],timeout:5,outputLimit:1024)
        #expect(flood.truncated);#expect(flood.stdout.count <= 1024)
    }
}
