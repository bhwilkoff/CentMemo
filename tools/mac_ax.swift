// Press and read the Mac app's controls through accessibility, by process id, without
// bringing it to the front. Needs the terminal's existing Accessibility permission; it
// never asks for it.
//   mac_ax <pid> dump | get <id> | ids <prefix> | state <id> | press <id> | type <id> <text> | clear <id>
// <id> is an accessibility identifier, or a control's exact title or label; `sheet-field`
// is the text field of an open alert.
import ApplicationServices
import Foundation

func attr(_ e: AXUIElement, _ n: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil
}
func str(_ e: AXUIElement, _ n: String) -> String { (attr(e, n) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func fail(_ s: String) -> Never { FileHandle.standardError.write((s + "\n").data(using: .utf8)!); exit(1) }
func name(_ e: AXUIElement) -> [String] {
    [str(e, "AXIdentifier"), str(e, kAXTitleAttribute), str(e, kAXDescriptionAttribute)]
}
func walk(_ e: AXUIElement, _ depth: Int = 0, _ visit: (AXUIElement, Int) -> Bool) -> Bool {
    if visit(e, depth) { return true }
    if depth > 40 { return false }
    for k in kids(e) where walk(k, depth + 1, visit) { return true }
    return false
}

let args = CommandLine.arguments
guard AXIsProcessTrusted() else { fail("BLIND: no Accessibility permission for this terminal") }
guard args.count >= 3, let pid = Int32(args[1]) else { fail("usage: mac_ax <pid> <verb> [id] [text]") }
let app = AXUIElementCreateApplication(pid)
// SwiftUI builds its accessibility tree only once a client asks for it.
if (attr(app, "AXEnhancedUserInterface") as? Bool) != true {
    AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
}
func windows() -> [AXUIElement] {
    let w = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    return w.isEmpty ? kids(app).filter { str($0, kAXRoleAttribute) == kAXWindowRole } : w
}
var roots = windows()
for _ in 0..<10 where roots.isEmpty {
    usleep(300_000)
    roots = windows()
}
if roots.isEmpty {
    var v: CFTypeRef?
    let e = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &v)
    fail("BLIND: no windows (AXError \(e.rawValue))")
}

/// Menu-bar items are asked for as `menu:Title`.
func menuItem(_ title: String) -> AXUIElement {
    var hit: AXUIElement?
    if let bar = attr(app, kAXMenuBarAttribute) {
        _ = walk(bar as! AXUIElement) { e, _ in
            if str(e, kAXRoleAttribute) == kAXMenuItemRole, str(e, kAXTitleAttribute) == title { hit = e; return true }
            return false
        }
    }
    guard let hit else { fail("not found: menu item \(title)") }
    return hit
}
func find(_ id: String) -> AXUIElement {
    if id.hasPrefix("menu:") { return menuItem(String(id.dropFirst(5))) }
    var hit: AXUIElement?
    if id == "sheet-field" {  // an alert's text field carries no name of its own
        for r in roots where hit == nil {
            _ = walk(r) { s, _ in
                str(s, kAXRoleAttribute) == kAXSheetRole && walk(s) { e, _ in
                    if str(e, kAXRoleAttribute) == kAXTextFieldRole { hit = e; return true }
                    return false
                }
            }
        }
        guard let hit else { fail("not found: sheet-field") }
        return hit
    }
    for i in 0..<3 {
        for r in roots where hit == nil {
            _ = walk(r) { e, _ in
                if name(e)[i] == id { hit = e; return true }
                return false
            }
        }
        if hit != nil { break }
    }
    guard let hit else { fail("not found: \(id)") }
    return hit
}
func textArea(_ id: String) -> AXUIElement {
    var t: AXUIElement?
    _ = walk(find(id)) { e, _ in
        let r = str(e, kAXRoleAttribute)
        if r == kAXTextAreaRole || r == kAXTextFieldRole { t = e; return true }
        return false
    }
    guard let t else { fail("no text in: \(id)") }
    return t
}
func check(_ r: AXError, _ what: String) { if r != .success { fail("\(what): AXError \(r.rawValue)") } }

switch args[2] {
case "dump":
    for r in roots {
        _ = walk(r) { e, d in
            let v = (attr(e, kAXValueAttribute) as? String) ?? ""
            let n = name(e).filter { !$0.isEmpty }.joined(separator: " | ")
            if args.contains("all") || !n.isEmpty || !v.isEmpty { print(String(repeating: " ", count: d) + str(e, kAXRoleAttribute), n, v.isEmpty ? "" : "= \(v.prefix(80))") }
            return false
        }
    }
case "get":
    let e = find(args[3])
    print((attr(e, kAXValueAttribute) as? String) ?? name(e).joined(separator: " "))
case "ids":  // the identifiers that begin with <id>
    for r in roots { _ = walk(r) { e, _ in
        if str(e, "AXIdentifier").hasPrefix(args[3]) { print(str(e, "AXIdentifier")) }
        return false
    } }
case "state":  // every attribute that can carry a chosen state
    let e = find(args[3])
    for n in ["AXSelected", "AXValue", "AXSubrole"] { if let v = attr(e, n) { print(n, v) } }
case "press":
    let e = find(args[3])
    if (attr(e, kAXEnabledAttribute) as? Bool) == false { fail("disabled: \(args[3])") }
    let r = AXUIElementPerformAction(e, kAXPressAction as CFString)
    // An alert's button reports an error because its sheet closes under the press.
    if r != .success, attr(e, kAXRoleAttribute) != nil { check(r, "press") }
case "type", "clear":
    let t = textArea(args[3])
    check(AXUIElementSetAttributeValue(t, kAXFocusedAttribute as CFString, kCFBooleanTrue), "focus")
    if args[2] == "clear" {
        var range = CFRange(location: 0, length: ((attr(t, kAXValueAttribute) as? String) ?? "").utf16.count)
        check(AXUIElementSetAttributeValue(t, kAXSelectedTextRangeAttribute as CFString, AXValueCreate(.cfRange, &range)!), "select")
    }
    check(AXUIElementSetAttributeValue(t, kAXSelectedTextAttribute as CFString, (args[2] == "clear" ? "" : args[4]) as CFString), "insert")
default: fail("unknown verb")
}
