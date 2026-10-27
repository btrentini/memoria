import AppKit
import Carbon

@MainActor final class GlobalShortcut {
    private var hotKey:EventHotKeyRef?
    private var handler:EventHandlerRef?
    private var action:(()->Void)?
    func register(key:String,action:@escaping ()->Void) -> String {
        unregister();self.action=action
        var spec=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        let context=Unmanaged.passUnretained(self).toOpaque()
        let status=InstallEventHandler(GetApplicationEventTarget(),{_,_,context in
            guard let context else {return OSStatus(eventNotHandledErr)}
            MainActor.assumeIsolated {Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action?()}
            return noErr
        },1,&spec,context,&handler)
        guard status == noErr else {return "Shortcut handler unavailable (\(status))"}
        let code:UInt32 = key == "F1" ? UInt32(kVK_F1):key == "F2" ? UInt32(kVK_F2):UInt32(kVK_Escape)
        let result=RegisterEventHotKey(code,UInt32(controlKey|shiftKey),EventHotKeyID(signature:0x4D454D4F,id:1),GetApplicationEventTarget(),0,&hotKey)
        return result == noErr ? "Control–Shift–\(key) registered":"Shortcut unavailable or already in use (\(result)). Choose another key."
    }
    func unregister() {if let hotKey {UnregisterEventHotKey(hotKey)};hotKey=nil;if let handler {RemoveEventHandler(handler)};handler=nil;action=nil}
}
