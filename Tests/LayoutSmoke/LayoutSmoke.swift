import AppKit
import SwiftUI

/// Runs the production layout with no collectors or process actions started.
@main struct LayoutSmoke:App {
    @State private var model=AppModel()
    var body:some Scene {
        Window("Memoria Layout Test",id:"layout-test") {
            MainView(model:model).frame(minWidth:1000,minHeight:650)
                .task {await runChecks()}
        }.defaultSize(width:1320,height:850)
    }
    @MainActor private func runChecks() async {
        guard let path=UserDefaults.standard.string(forKey:"layoutOutput") else {NSApp.terminate(nil);return}
        let output=URL(fileURLWithPath:path,isDirectory:true)
        var checks=0,failures:[String]=[]
        func check(_ condition:Bool,_ message:String) {checks += 1;if !condition {failures.append(message)}}
        model.destination = .applications;model.simplifiedView=false;model.inspectorVisible=true
        await settle()
        guard let window=NSApp.windows.first(where:{$0.title == "Memoria Layout Test"}),let content=window.contentView else {
            try? Data("{\"failures\":[\"No test window\"]}".utf8).write(to:output.appendingPathComponent("result.json"))
            NSApp.terminate(nil);return
        }
        window.makeKeyAndOrderFront(nil)
        func verify(_ name:String,panes:Int) {
            content.layoutSubtreeIfNeeded()
            guard let root=splitViews(content).first else {check(false,name+": missing split");return}
            check(root.arrangedSubviews.count == panes,name+": wrong pane count")
            check(abs(root.bounds.width-content.bounds.width)<1,name+": root exceeds window width")
            for split in splitViews(content) {
                let frame=split.convert(split.bounds,to:content)
                check(frame.minX >= -1 && frame.maxX <= content.bounds.width+1,name+": clipped split")
                if split.isVertical {
                    var right:CGFloat = 0
                    for pane in split.arrangedSubviews where !pane.isHidden {
                        check(pane.frame.minX >= right-1,name+": overlapping panes")
                        right=pane.frame.maxX
                    }
                    check(right <= split.bounds.width+1,name+": pane exceeds divider bounds")
                }
            }
        }
        func capture(_ name:String) {
            let view=content.superview ?? content
            view.displayIfNeeded()
            guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else {return}
            view.cacheDisplay(in:view.bounds,to:bitmap)
            try? bitmap.representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent(name+".png"))
        }
        for (name,width,divider) in [("wide",1320.0,240.0),("minimum",1000.0,240.0),("drag-wide",1000.0,300.0),("drag-narrow",1000.0,220.0),("wide-again",1320.0,300.0)] {
            window.setContentSize(NSSize(width:width,height:650));await settle()
            splitViews(content).first?.setPosition(divider,ofDividerAt:0);await settle()
            verify(name,panes:3)
            let sidebar=splitViews(content).first?.arrangedSubviews.first?.frame.width ?? 0
            check(sidebar >= 219 && sidebar <= 301,name+": sidebar width outside limits")
            if name == "minimum" || name == "wide" {capture(name)}
        }
        for index in 0..<6 {
            window.setContentSize(NSSize(width:index.isMultiple(of:2) ? 1000:1320,height:750));await settle()
            verify("resize cycle \(index)",panes:3)
        }
        for (name,panes) in [("sidebar hidden",2),("sidebar restored",3)] {
            let event=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.command,.control],
                timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,
                characters:"s",charactersIgnoringModifiers:"s",isARepeat:false,keyCode:1)
            check(event.map {window.performKeyEquivalent(with:$0)} == true,name+": sidebar shortcut failed")
            await settle();verify(name,panes:panes)
        }
        capture("sidebar-restored")
        model.inspectorVisible=false;await settle();verify("inspector hidden",panes:2)
        model.inspectorVisible=true;await settle();verify("inspector restored",panes:3)
        for simple in [false,true] {
            model.simplifiedView=simple
            window.setContentSize(NSSize(width:1000,height:650))
            for destination in Destination.allCases {
                model.destination=destination;await settle()
                verify(destination.rawValue+(simple ? " Simple":" Full"),panes:simple ? 2:3)
            }
        }
        try? JSONSerialization.data(withJSONObject:["checks":checks,"failures":failures,"scope":"Production window layout without telemetry or process actions"],options:.prettyPrinted)
            .write(to:output.appendingPathComponent("result.json"))
        NSApp.terminate(nil)
    }
    @MainActor private func settle() async {try? await Task.sleep(for:.milliseconds(350))}
    @MainActor private func splitViews(_ view:NSView)->[NSSplitView] {
        ([view as? NSSplitView].compactMap {$0})+view.subviews.flatMap {splitViews($0)}
    }
}
