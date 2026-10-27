import SwiftUI
import AppKit
import MemoriaCore

/// AppKit virtualises visible rows; ancestry remains an observed relationship.
struct NativeProcessOutline:NSViewRepresentable {
    let model:AppModel
    let rows:[ProcessSnapshot]
    let context:ProcessListContext
    let sort:ProcessSort
    let descending:Bool
    let sortChanged:(ProcessSort,Bool)->Void
    func makeCoordinator() -> Coordinator {Coordinator(model,sortChanged:sortChanged)}
    func makeNSView(context:Context) -> NSScrollView {
        let scroll=NSScrollView(),view=NSOutlineView()
        view.delegate=context.coordinator;view.dataSource=context.coordinator
        view.rowHeight=33;view.usesAlternatingRowBackgroundColors=true
        view.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        for (key,title,width) in [("name","Process tree",260.0),("pid","PID",70),("cpu","CPU %",90),("memory","Footprint",110)] {
            let column=NSTableColumn(identifier:.init(key));column.title=title;column.width=width
            column.sortDescriptorPrototype=NSSortDescriptor(key:key,ascending:false);view.addTableColumn(column)
        }
        view.outlineTableColumn=view.tableColumns.first;view.autosaveName="MemoriaTreeColumns."+self.context.rawValue;view.autosaveTableColumns=true
        view.setAccessibilityLabel("Process ancestry tree")
        context.coordinator.view=view
        let menu=NSMenu()
        for (title,selector) in [("Inspect",#selector(Coordinator.inspect)),("Terminate…",#selector(Coordinator.terminate)),("Force Kill…",#selector(Coordinator.force)),("Review Process Tree…",#selector(Coordinator.tree))] {
            let item=NSMenuItem(title:title,action:selector,keyEquivalent:"");item.target=context.coordinator;menu.addItem(item)
        }
        view.menu=menu;scroll.documentView=view;scroll.hasVerticalScroller=true;scroll.hasHorizontalScroller=true
        return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        let coordinator=context.coordinator;coordinator.sortChanged=sortChanged
        coordinator.update(rows)
        coordinator.updating=true
        let descriptor=NSSortDescriptor(key:sort.rawValue,ascending:!descending)
        if coordinator.view?.sortDescriptors != [descriptor] {coordinator.view?.sortDescriptors=[descriptor]}
        coordinator.updating=false
    }

    @MainActor final class Node:NSObject {
        let process:ProcessSnapshot
        var children:[Node]=[]
        init(_ process:ProcessSnapshot) {self.process=process}
    }
    @MainActor final class Coordinator:NSObject,NSOutlineViewDataSource,NSOutlineViewDelegate {
        let model:AppModel
        weak var view:NSOutlineView?
        var roots:[Node]=[],nodes:[ProcessIdentity:Node]=[:]
        var updating=false
        var sortChanged:(ProcessSort,Bool)->Void
        init(_ model:AppModel,sortChanged:@escaping (ProcessSort,Bool)->Void) {self.model=model;self.sortChanged=sortChanged}
        func update(_ rows:[ProcessSnapshot]) {
            guard let view else {return}
            updating=true;defer{updating=false}
            let expanded=Set(nodes.values.filter{view.isItemExpanded($0)}.map(\.process.identity))
            let first=nodes.isEmpty
            nodes=Dictionary(rows.map{($0.identity,Node($0))},uniquingKeysWith:{a,_ in a})
            let byPID=Dictionary(rows.map{($0.identity.pid,$0)},uniquingKeysWith:{a,_ in a})
            roots=[]
            for process in rows {
                guard let node=nodes[process.identity] else {continue}
                var seen:Set<Int32>=[process.identity.pid],ancestor=process.parentPID,cycle=false
                for _ in 0..<64 {
                    guard let parent=byPID[ancestor] else {break}
                    if !seen.insert(ancestor).inserted {cycle=true;break}
                    ancestor=parent.parentPID
                }
                if !cycle,let parent=byPID[process.parentPID],parent.identity.startSeconds<=process.identity.startSeconds,
                   let parentNode=nodes[parent.identity] {parentNode.children.append(node)}
                else {roots.append(node)}
            }
            view.reloadData()
            for node in nodes.values where expanded.contains(node.process.identity) {view.expandItem(node)}
            if first {for node in roots {view.expandItem(node)}}
            if let selected=model.selected,let node=nodes[selected] {
                let row=view.row(forItem:node)
                if row>=0 {view.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false)}
            }
        }
        func outlineView(_ outlineView:NSOutlineView,numberOfChildrenOfItem item:Any?) -> Int {(item as? Node)?.children.count ?? roots.count}
        func outlineView(_ outlineView:NSOutlineView,child index:Int,ofItem item:Any?) -> Any {(item as? Node)?.children[index] ?? roots[index]}
        func outlineView(_ outlineView:NSOutlineView,isItemExpandable item:Any) -> Bool {!((item as? Node)?.children.isEmpty ?? true)}
        func outlineView(_ outlineView:NSOutlineView,viewFor tableColumn:NSTableColumn?,item:Any) -> NSView? {
            guard let node=item as? Node,let column=tableColumn else {return nil}
            let id=column.identifier,p=node.process
            let cell=(outlineView.makeView(withIdentifier:id,owner:self) as? NSTableCellView) ?? NSTableCellView()
            if cell.textField == nil {
                let label=NSTextField(labelWithString:"");label.translatesAutoresizingMaskIntoConstraints=false;label.lineBreakMode = .byTruncatingTail
                cell.addSubview(label);cell.textField=label;cell.identifier=id
                NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo:cell.leadingAnchor,constant:5),label.trailingAnchor.constraint(equalTo:cell.trailingAnchor,constant:-5),label.centerYAnchor.constraint(equalTo:cell.centerYAnchor)])
            }
            cell.textField?.stringValue=switch id.rawValue {case "name":p.name;case "pid":String(p.identity.pid);case "cpu":Format.percent(p.cpuPercent);default:Format.bytes(p.footprintBytes)}
            cell.textField?.font=id.rawValue == "name" ? .systemFont(ofSize:13):.monospacedDigitSystemFont(ofSize:12,weight:.regular)
            cell.toolTip="Observed parent PID \(p.parentPID). Filtering can hide ancestors."
            return cell
        }
        func outlineViewSelectionDidChange(_ notification:Notification) {
            guard !updating,let view,let node=view.item(atRow:view.selectedRow) as? Node else {return}
            model.selected=node.process.identity
        }
        func outlineView(_ outlineView:NSOutlineView,sortDescriptorsDidChange oldDescriptors:[NSSortDescriptor]) {
            guard !updating,let descriptor=outlineView.sortDescriptors.first,let key=descriptor.key,let sort=ProcessSort(rawValue:key) else{return}
            sortChanged(sort,!descriptor.ascending)
        }
        func clicked() {
            guard let view else{return}
            if let node=view.item(atRow:view.clickedRow>=0 ? view.clickedRow:view.selectedRow) as? Node {model.selected=node.process.identity}
        }
        @objc func inspect() {clicked();model.inspectorVisible=true;model.loadDetails()}
        @objc func terminate() {clicked();model.prepare(.terminate)}
        @objc func force() {clicked();model.prepare(.forceKill)}
        @objc func tree() {clicked();model.prepare(.terminate,tree:true)}
    }
}
