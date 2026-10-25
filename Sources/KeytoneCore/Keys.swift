import Foundation

/// Fase de una pulsación: bajar la tecla o soltarla.
public enum KeyPhase: String, Hashable, CaseIterable, Sendable {
    case press
    case release
}

/// Familias de teclas que suenan distinto en un teclado real.
public enum KeyKind: String, Hashable, CaseIterable, Sendable {
    case normal
    case space
    case enter
    case backspace
    case modifier
    case mouse
}

/// Información física de las teclas de un teclado ANSI de Mac (códigos virtuales de macOS).
public enum KeyLayout {
    public static let space: UInt16 = 49
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let delete: UInt16 = 51
    public static let forwardDelete: UInt16 = 117
    public static let capsLock: UInt16 = 57

    /// Códigos de modificadores (Shift, Control, Option, Command, Fn y Caps Lock).
    public static let modifiers: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    public static func kind(for keyCode: UInt16) -> KeyKind {
        switch keyCode {
        case space: return .space
        case returnKey, keypadEnter: return .enter
        case delete, forwardDelete: return .backspace
        case _ where modifiers.contains(keyCode): return .modifier
        default: return .normal
        }
    }

    /// Posición horizontal de la tecla (0 = izquierda, 1 = derecha), para el panorama estéreo.
    public static func horizontalPosition(for keyCode: UInt16) -> Float {
        positions[keyCode] ?? 0.5
    }

    private static let positions: [UInt16: Float] = {
        // Cada fila: desplazamiento inicial (en anchos de tecla) y sus códigos de izquierda a derecha.
        let rows: [(Float, [UInt16])] = [
            (0.0, [53, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]),
            (0.0, [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51]),
            (0.5, [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42]),
            (0.8, [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36]),
            (1.2, [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60]),
        ]
        let width: Float = 15
        var map: [UInt16: Float] = [:]
        for (offset, codes) in rows {
            for (index, code) in codes.enumerated() {
                map[code] = min(1, (offset + Float(index) + 0.5) / width)
            }
        }
        // Fila inferior y teclas sueltas.
        map[63] = 0.03; map[59] = 0.09; map[58] = 0.16; map[55] = 0.25
        map[49] = 0.5
        map[54] = 0.72; map[61] = 0.79; map[62] = 0.85
        map[123] = 0.86; map[125] = 0.92; map[126] = 0.92; map[124] = 0.98
        map[115] = 0.95; map[119] = 0.95; map[116] = 0.97; map[121] = 0.97; map[117] = 0.96
        map[76] = 1.0
        return map
    }()
}
