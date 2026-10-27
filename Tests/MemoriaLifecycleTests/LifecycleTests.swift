import Foundation
import Testing
import MemoriaLifecycle

@MainActor private final class FakeLoginManager:LoginItemManaging {
    var state:LoginItemState = .disabled
    var registrationAllowed=true
    var registers=0,unregisters=0
    var requiresApproval=false,denied=false
    func register() throws {
        registers += 1
        if denied {throw CocoaError(.userCancelled)}
        state=requiresApproval ? .approvalRequired:.enabled
    }
    func unregister() async throws {unregisters += 1;state = .disabled}
    func openSettings() {}
}
@Suite("Menu-bar lifecycle and login policy") @MainActor struct LifecycleTests {
    @Test func explicitEnableAndDisableAreIdempotent() async {
        let manager=FakeLoginManager()
        let subject=BackgroundLifecycle(manager:manager)
        #expect(!subject.loginRequested && manager.registers==0)
        await subject.setLoginEnabled(true);await subject.setLoginEnabled(true)
        #expect(manager.registers==1 && subject.loginState == .enabled)
        await subject.setLoginEnabled(false);await subject.setLoginEnabled(false)
        #expect(manager.unregisters==1 && subject.loginState == .disabled)
    }
    @Test func pendingApprovalIsDistinctFromEnabled() async {
        let manager=FakeLoginManager();manager.requiresApproval=true
        let subject=BackgroundLifecycle(manager:manager)
        await subject.setLoginEnabled(true)
        #expect(subject.loginRequested && subject.loginState == .approvalRequired)
        #expect(subject.statusText.contains("Approval"))
    }
    @Test func revocationDoesNotSilentlyRegisterAgain() async {
        let manager=FakeLoginManager()
        let value=BackgroundLifecycle(manager:manager)
        await value.setLoginEnabled(true);manager.state = .disabled;value.refresh()
        #expect(!value.loginRequested && manager.registers==1)
    }
    @Test func denialAndTemporaryInstallFailWithoutClaimingEnabled() async {
        let manager=FakeLoginManager();manager.denied=true
        let subject=BackgroundLifecycle(manager:manager)
        await subject.setLoginEnabled(true)
        #expect(subject.errorMessage != nil && !subject.loginRequested && !subject.busy)
        manager.registrationAllowed=false
        await subject.setLoginEnabled(true)
        #expect(manager.registers==1 && subject.errorMessage?.contains("Applications")==true)
    }
    @Test func installationBoundaryRejectsTemporarySiblingAndTraversalPaths() {
        let roots=[URL(fileURLWithPath:"/Applications")]
        #expect(LoginInstallation.isPermanent(URL(fileURLWithPath:"/Applications/Memoria.app"),roots:roots))
        #expect(!LoginInstallation.isPermanent(URL(fileURLWithPath:"/ApplicationsOther/Memoria.app"),roots:roots))
        #expect(!LoginInstallation.isPermanent(URL(fileURLWithPath:"/Applications/../private/tmp/Memoria.app"),roots:roots))
        #expect(!LoginInstallation.isPermanent(URL(fileURLWithPath:"/Applications/Memoria.app/Contents/MacOS/Memoria"),roots:roots))
    }
}
