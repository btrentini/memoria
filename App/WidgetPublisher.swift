import Foundation
import WidgetKit
import MemoriaWidgetSupport

actor WidgetPublisher {
    private struct Request:Sendable {
        let summary:WidgetSummary
        let enabled:Bool
        let now:Double
        let force:Bool
    }
    private let store:SummaryStore? = WidgetGroup.directory().map(SummaryStore.init(directory:))
    private var policy=SummaryPublicationPolicy()
    private var pending:Request?
    private var draining=false
    private var control:String?
    private var status="Waiting for a snapshot"
    func publish(_ summary:WidgetSummary,enabled:Bool,now:Double,force:Bool=false) async -> String {
        guard let store else {return enabled ? "Unavailable: a signed App Group is required for desktop widgets.":"Widget sharing disabled"}
        pending=Request(summary:summary,enabled:enabled,now:now,force:force)
        guard !draining else {return "Updating widget snapshot…"}
        draining=true
        defer {draining=false}
        while let request=pending {
            pending=nil
            let next=request.enabled ? request.summary.state.rawValue:"disabled"
            let changed=control != next
            if !request.enabled && !changed && !request.force {continue}
            guard policy.shouldAttempt(now:request.now,state:next,force:request.force) else {continue}
            do {
                if request.enabled {try await store.write(request.summary)} else {try await store.remove()}
                control=next
                if policy.shouldReload(now:request.now,force:changed || request.force) {
                    await MainActor.run {WidgetCenter.shared.reloadTimelines(ofKind:WidgetSummary.kind)}
                }
                status=request.enabled ? "Aggregate snapshot shared; macOS schedules widget refreshes.":"Widget cache deleted; sharing disabled."
            } catch {status="Widget snapshot unavailable: \(error)"}
        }
        return status
    }
}
