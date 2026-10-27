import AppKit
import SwiftUI
import MemoriaStoreMetrics
import MemoriaWidgetSupport

struct StoreHistoryPoint:Identifiable {
    let date:Date,cpu:Double?,memory:Double?
    var id:Date {date}
}
@MainActor @Observable final class StoreModel {
    private let collector=StoreCollector()
    private let publisher=WidgetPublisher()
    private var task:Task<Void,Never>?
    private var previous:StoreSnapshot?
    private let pressureSource=DispatchSource.makeMemoryPressureSource(eventMask:[.normal,.warning,.critical],queue:.main)
    var snapshot:StoreSnapshot?
    var history:[StoreHistoryPoint]=[]
    var pressure:SummaryPressure = .unknown
    var widgetStatus="Widget sharing is off"
    var paused=false
    var selection:StorePage = .overview
    var simple=UserDefaults.standard.object(forKey:"store.simple") as? Bool ?? true {
        didSet {UserDefaults.standard.set(simple,forKey:"store.simple")}
    }
    var shareWidget=UserDefaults.standard.bool(forKey:"store.widget") {
        didSet {
            UserDefaults.standard.set(shareWidget,forKey:"store.widget")
            Task {await publish(force:true)}
        }
    }
    var interval=UserDefaults.standard.double(forKey:"store.interval")==5 ? 5.0:2.0 {
        didSet {UserDefaults.standard.set(interval,forKey:"store.interval")}
    }
    var menuReading=MenuBarReading(rawValue:UserDefaults.standard.string(forKey:"store.menu") ?? "") ?? .both {
        didSet {UserDefaults.standard.set(menuReading.rawValue,forKey:"store.menu")}
    }
    init() {
        pressureSource.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else {return}
                let value=self.pressureSource.data
                self.pressure=value.contains(.critical) ? .critical:value.contains(.warning) ? .warning:value.contains(.normal) ? .normal:.unknown
            }
        }
        pressureSource.resume()
        task=Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {return}
                if !self.paused {
                    let raw=await self.collector.sample()
                    guard !Task.isCancelled else {return}
                    if !self.paused {
                        let value=StoreDeltas.apply(raw,previous:self.previous)
                        self.previous=raw;self.snapshot=value
                        self.history.append(StoreHistoryPoint(date:value.date,cpu:value.cpu,memory:value.memory?.percent))
                        self.history.removeAll {$0.date<value.date.addingTimeInterval(-3600)}
                        if self.history.count>1800 {self.history.removeFirst(self.history.count-1800)}
                        await self.publish()
                    }
                }
                let delay=ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical ? max(5,self.interval):self.interval
                do {try await Task.sleep(for:.seconds(delay))} catch {return}
            }
        }
    }
    func togglePaused() {
        paused.toggle();previous=nil
        if paused {snapshot=nil;history.append(StoreHistoryPoint(date:.now,cpu:nil,memory:nil))}
        Task {await publish(force:true)}
    }
    func publish(force:Bool=false) async {
        let now=Date.now
        let points=history.filter {$0.date>=now.addingTimeInterval(-120) && $0.date<=now}.suffix(30).map {SummaryPoint(date:$0.date,cpu:$0.cpu)}
        let summary=WidgetSummary(capturedAt:now,state:paused ? .paused:.captured,
                                  cpuPercent:paused ? nil:snapshot?.cpu,
                                  accountedMemory:paused ? nil:snapshot?.memory?.accounted,
                                  totalMemory:paused ? nil:snapshot?.memory?.total,
                                  pressure:pressure,history:paused ? []:points)
        widgetStatus=await publisher.publish(summary,enabled:shareWidget,now:ProcessInfo.processInfo.systemUptime,force:force)
    }
    var menuText:String {menuReading.text(cpu:snapshot?.cpu,memory:snapshot?.memory?.accounted,paused:paused)}
}
enum StorePage:String,CaseIterable,Identifiable {
    case overview="Overview",cpu="CPU",memory="Memory",network="Network",power="Power",privacy="Privacy"
    var id:Self {self}
    var symbol:String {switch self {case .overview:"square.grid.2x2";case .cpu:"cpu";case .memory:"memorychip";case .network:"network";case .power:"battery.100percent";case .privacy:"hand.raised"}}
}
func storeBytes(_ bytes:UInt64?) -> String {bytes.map {ByteCountFormatter.string(fromByteCount:Int64(clamping:$0),countStyle:.memory)} ?? "—"}
func storePercent(_ percent:Double?) -> String {percent.map {String(format:"%.1f%%",$0)} ?? "—"}
