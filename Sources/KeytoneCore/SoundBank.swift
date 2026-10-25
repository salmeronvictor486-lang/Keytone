import Foundation

/// Conjunto de muestras mono a 48 kHz listas para reproducir.
public final class SoundBank {
    private struct Slot: Hashable {
        let kind: KeyKind
        let phase: KeyPhase
    }

    public let name: String
    private var slots: [Slot: [[Float]]] = [:]
    private var perKey: [KeyPhase: [UInt16: [Float]]] = [:]
    private var lastPick: [Slot: Int] = [:]

    public init(name: String) {
        self.name = name
    }

    public var isEmpty: Bool {
        slots.isEmpty && perKey.values.allSatisfy(\.isEmpty)
    }

    public var sampleCount: Int {
        slots.values.reduce(0) { $0 + $1.count } + perKey.values.reduce(0) { $0 + $1.count }
    }

    public func add(_ sample: [Float], kind: KeyKind, phase: KeyPhase) {
        guard !sample.isEmpty else { return }
        slots[Slot(kind: kind, phase: phase), default: []].append(sample)
    }

    /// Sonido específico para una tecla concreta (packs de Mechvibes).
    public func set(_ sample: [Float], keyCode: UInt16, phase: KeyPhase) {
        guard !sample.isEmpty else { return }
        perKey[phase, default: [:]][keyCode] = sample
    }

    public func hasSamples(kind: KeyKind, phase: KeyPhase) -> Bool {
        slots[Slot(kind: kind, phase: phase)] != nil
    }

    /// Elige una muestra evitando repetir la última de su grupo.
    public func sample(keyCode: UInt16, kind: KeyKind, phase: KeyPhase) -> [Float]? {
        if kind != .mouse, let exact = perKey[phase]?[keyCode] {
            return exact
        }
        var slot = Slot(kind: kind, phase: phase)
        if slots[slot] == nil, kind != .mouse {
            slot = Slot(kind: .normal, phase: phase)
        }
        guard let options = slots[slot], !options.isEmpty else {
            // Sin muestras genéricas: usa cualquiera de las asignadas por tecla.
            if kind != .mouse, let any = perKey[phase]?.values.randomElement() {
                return any
            }
            return nil
        }
        guard options.count > 1 else { return options[0] }
        var index = Int.random(in: 0..<options.count)
        if index == lastPick[slot] {
            index = (index + 1) % options.count
        }
        lastPick[slot] = index
        return options[index]
    }
}
