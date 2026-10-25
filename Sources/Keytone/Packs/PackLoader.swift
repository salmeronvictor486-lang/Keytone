import Foundation
import KeytoneCore

enum PackError: LocalizedError {
    case empty(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .empty(let name):
            return "«\(name)» no contiene sonidos que macOS pueda leer (WAV, MP3, M4A, AIFF, CAF o FLAC). Si son .ogg, conviértelos con: for f in *.ogg; do ffmpeg -i \"$f\" \"${f%.ogg}.wav\"; done"
        case .invalid(let reason):
            return reason
        }
    }
}

/// Carga packs de sonido desde carpetas: formato Mechvibes (config.json) o carpeta de audios.
enum PackLoader {
    static func load(folder: URL) throws -> SoundBank {
        let config = folder.appendingPathComponent("config.json")
        if FileManager.default.fileExists(atPath: config.path) {
            return try loadMechvibes(folder: folder, configURL: config)
        }
        return try loadLooseFiles(folder: folder)
    }

    static func displayName(for folder: URL) -> String {
        let config = folder.appendingPathComponent("config.json")
        if let parsed = try? MechvibesConfig.load(from: config), !parsed.name.isEmpty {
            return parsed.name
        }
        return folder.lastPathComponent
    }

    // MARK: - Mechvibes

    private static func loadMechvibes(folder: URL, configURL: URL) throws -> SoundBank {
        let config: MechvibesConfig
        do {
            config = try MechvibesConfig.load(from: configURL)
        } catch {
            throw PackError.invalid("El config.json de «\(folder.lastPathComponent)» no es válido: \(error.localizedDescription)")
        }

        var entries: [(sample: [Float], keyCode: UInt16, phase: KeyPhase)] = []
        let sr = Double(SwitchSynth.sampleRate)

        switch config.type {
        case .single:
            guard let soundName = config.sound else { throw PackError.invalid("Falta el campo \"sound\" en config.json.") }
            let full = try AudioDecoder.decodeMono(folder.appendingPathComponent(soundName))
            for (key, define) in config.defines {
                guard case let .slice(start, duration) = define, let target = MechvibesConfig.resolve(key) else { continue }
                let from = max(0, min(full.count, Int(start / 1000 * sr)))
                let to = max(from, min(full.count, from + Int(duration / 1000 * sr)))
                var slice = Array(full[from..<to])
                fadeOut(&slice)
                entries.append((slice, target.keyCode, target.phase))
            }
        case .multi:
            var cache: [String: [Float]] = [:]
            for (key, define) in config.defines {
                guard case let .file(name) = define, let target = MechvibesConfig.resolve(key) else { continue }
                if cache[name] == nil {
                    cache[name] = (try? AudioDecoder.decodeMono(folder.appendingPathComponent(name))) ?? []
                }
                entries.append((cache[name] ?? [], target.keyCode, target.phase))
            }
        }

        entries.removeAll { $0.sample.isEmpty }
        guard !entries.isEmpty else { throw PackError.empty(config.name) }

        // Nivela el volumen del pack para que no suene más fuerte que los integrados.
        let peak = entries.reduce(Float(0)) { max($0, DSP.peak($1.sample)) }
        let gain = peak > 0 ? 0.85 / peak : 1
        let bank = SoundBank(name: config.name)
        for entry in entries {
            let sample = entry.sample.map { $0 * gain }
            bank.set(sample, keyCode: entry.keyCode, phase: entry.phase)
            bank.add(sample, kind: KeyLayout.kind(for: entry.keyCode), phase: entry.phase)
        }
        return bank
    }

    // MARK: - Carpeta de audios

    /// Clasifica por nombre: «space», «enter», «backspace», «shift», «mouse»… y «release»/«up» para soltar.
    private static func loadLooseFiles(folder: URL) throws -> SoundBank {
        let name = folder.lastPathComponent
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else {
            throw PackError.empty(name)
        }
        var entries: [(sample: [Float], kind: KeyKind, phase: KeyPhase)] = []
        for case let url as URL in enumerator where AudioDecoder.supportedExtensions.contains(url.pathExtension.lowercased()) {
            let relative = url.path.dropFirst(folder.path.count).lowercased()
            guard let sample = try? AudioDecoder.decodeMono(url), !sample.isEmpty else { continue }
            entries.append((sample, kind(from: relative), phase(from: relative)))
        }
        guard !entries.isEmpty else { throw PackError.empty(name) }

        let peak = entries.reduce(Float(0)) { max($0, DSP.peak($1.sample)) }
        let gain = peak > 0 ? 0.85 / peak : 1
        let bank = SoundBank(name: name)
        for entry in entries {
            bank.add(entry.sample.map { $0 * gain }, kind: entry.kind, phase: entry.phase)
        }
        return bank
    }

    private static func kind(from path: String) -> KeyKind {
        if path.contains("space") { return .space }
        if path.contains("enter") || path.contains("return") { return .enter }
        if path.contains("back") || path.contains("delete") { return .backspace }
        if ["shift", "mod", "cmd", "command", "ctrl", "control", "alt", "option"].contains(where: { path.contains($0) }) { return .modifier }
        if path.contains("mouse") { return .mouse }
        return .normal
    }

    private static func phase(from path: String) -> KeyPhase {
        let markers = ["release", "keyup", "key_up", "key-up", "_up.", "-up.", " up.", "/up/", "/release/"]
        return markers.contains(where: { path.contains($0) }) ? .release : .press
    }

    private static func fadeOut(_ buffer: inout [Float]) {
        let fade = min(buffer.count, Int(SwitchSynth.sampleRate * 0.003))
        guard fade > 0 else { return }
        let start = buffer.count - fade
        for i in start..<buffer.count {
            buffer[i] *= Float(buffer.count - i) / Float(fade)
        }
    }
}
