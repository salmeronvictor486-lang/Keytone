import Foundation

/// Lectura del formato de packs de Mechvibes (config.json), el más usado por la comunidad.
public struct MechvibesConfig: Decodable {
    public enum DefineType: String, Decodable {
        case single
        case multi
    }

    public enum Define {
        /// Fragmento [inicio, duración] en milisegundos dentro del archivo único.
        case slice(start: Double, duration: Double)
        /// Archivo propio para esa tecla.
        case file(String)
    }

    public var name: String
    public var type: DefineType
    public var sound: String?
    /// Clave: código de Mechvibes (con sufijo "-up" para soltar la tecla).
    public var defines: [String: Define]

    private enum CodingKeys: String, CodingKey {
        case name
        case type = "key_define_type"
        case sound
        case defines
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Pack"
        type = (try? c.decode(DefineType.self, forKey: .type)) ?? .single
        sound = try? c.decode(String.self, forKey: .sound)

        let raw = try c.nestedContainer(keyedBy: AnyKey.self, forKey: .defines)
        var parsed: [String: Define] = [:]
        for key in raw.allKeys {
            if let pair = try? raw.decode([Double].self, forKey: key), pair.count >= 2 {
                parsed[key.stringValue] = .slice(start: pair[0], duration: pair[1])
            } else if let file = try? raw.decode(String.self, forKey: key), !file.isEmpty {
                parsed[key.stringValue] = .file(file)
            }
        }
        defines = parsed
    }

    public static func load(from url: URL) throws -> MechvibesConfig {
        try JSONDecoder().decode(MechvibesConfig.self, from: Data(contentsOf: url))
    }

    /// Convierte una clave de `defines` en (código de macOS, fase).
    public static func resolve(_ key: String) -> (keyCode: UInt16, phase: KeyPhase)? {
        var code = key
        var phase = KeyPhase.press
        if code.hasSuffix("-up") {
            code = String(code.dropLast(3))
            phase = .release
        }
        guard let value = Int(code), let mac = macKeyCode[value] else { return nil }
        return (mac, phase)
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    }

    /// Códigos de Mechvibes (iohook, basados en scancodes) → códigos virtuales de macOS.
    public static let macKeyCode: [Int: UInt16] = [
        1: 53, 59: 122, 60: 120, 61: 99, 62: 118, 63: 96, 64: 97, 65: 98, 66: 100, 67: 101, 68: 109, 87: 103, 88: 111,
        41: 50, 2: 18, 3: 19, 4: 20, 5: 21, 6: 23, 7: 22, 8: 26, 9: 28, 10: 25, 11: 29, 12: 27, 13: 24, 14: 51,
        15: 48, 16: 12, 17: 13, 18: 14, 19: 15, 20: 17, 21: 16, 22: 32, 23: 34, 24: 31, 25: 35, 26: 33, 27: 30, 43: 42,
        58: 57, 30: 0, 31: 1, 32: 2, 33: 3, 34: 5, 35: 4, 36: 38, 37: 40, 38: 37, 39: 41, 40: 39, 28: 36,
        42: 56, 44: 6, 45: 7, 46: 8, 47: 9, 48: 11, 49: 45, 50: 46, 51: 43, 52: 47, 53: 44, 54: 60,
        29: 59, 56: 58, 3675: 55, 57: 49, 3676: 54, 3640: 61, 3613: 62,
        57416: 126, 57419: 123, 57421: 124, 57424: 125,
        3667: 117, 3655: 115, 3663: 119, 3657: 116, 3665: 121, 3612: 76,
        // Teclado numérico
        69: 71, 3637: 75, 55: 67, 74: 78, 71: 89, 72: 91, 73: 92, 78: 69, 75: 86, 76: 87, 77: 88,
        79: 83, 80: 84, 81: 85, 82: 82, 83: 65,
    ]
}
