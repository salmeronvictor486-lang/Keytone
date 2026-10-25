import AppKit
import CoreGraphics
import KeytoneCore

struct InputEvent {
    let keyCode: UInt16
    let kind: KeyKind
    let phase: KeyPhase
    let isRepeat: Bool
    let flags: CGEventFlags
}

/// Escucha (sin modificar) el teclado y el ratón de todo el sistema mediante un event tap.
/// Requiere el permiso de "Monitorización de entrada".
final class InputMonitor {
    var handler: ((InputEvent) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var heldModifiers: Set<UInt16> = []

    var isRunning: Bool { tap != nil }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    static func requestPermission() {
        _ = CGRequestListenEventAccess()
    }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasPermission else { return false }

        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: inputTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        heldModifiers.removeAll()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }

        case .keyDown, .keyUp:
            let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            emit(code, type == .keyDown ? .press : .release, isRepeat: isRepeat, flags: event.flags)

        case .flagsChanged:
            let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            if code == KeyLayout.capsLock {
                // Caps Lock solo avisa al cambiar de estado: simulamos pulsar y soltar.
                emit(code, .press, isRepeat: false, flags: event.flags)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.emit(code, .release, isRepeat: false, flags: [])
                }
            } else if heldModifiers.contains(code) {
                heldModifiers.remove(code)
                emit(code, .release, isRepeat: false, flags: event.flags)
            } else if let mask = Self.modifierMask(code), event.flags.contains(mask) {
                heldModifiers.insert(code)
                emit(code, .press, isRepeat: false, flags: event.flags)
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            emitMouse(.press, flags: event.flags)

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            emitMouse(.release, flags: event.flags)

        default:
            break
        }
    }

    private func emit(_ code: UInt16, _ phase: KeyPhase, isRepeat: Bool, flags: CGEventFlags) {
        handler?(InputEvent(keyCode: code, kind: KeyLayout.kind(for: code), phase: phase, isRepeat: isRepeat, flags: flags))
    }

    private func emitMouse(_ phase: KeyPhase, flags: CGEventFlags) {
        handler?(InputEvent(keyCode: UInt16.max, kind: .mouse, phase: phase, isRepeat: false, flags: flags))
    }

    private static func modifierMask(_ code: UInt16) -> CGEventFlags? {
        switch code {
        case 56, 60: return .maskShift
        case 59, 62: return .maskControl
        case 58, 61: return .maskAlternate
        case 54, 55: return .maskCommand
        case 63: return .maskSecondaryFn
        default: return nil
        }
    }
}

private func inputTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
