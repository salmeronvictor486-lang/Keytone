import AppKit
import KeytoneCore

struct PackInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let category: SwitchCategory
    let folder: URL?

    var isImported: Bool { folder != nil }
}

/// Catálogo de packs: los sintetizados de serie y los importados por el usuario.
final class PackLibrary: ObservableObject {
    static let defaultID = "mx-blue"

    let builtIn: [PackInfo] = SwitchProfile.all.map {
        PackInfo(id: $0.id, name: $0.name, subtitle: $0.subtitle, category: $0.category, folder: nil)
    }

    @Published private(set) var imported: [PackInfo] = []

    private var cache: [String: SoundBank] = [:]
    private let cacheLock = NSLock()

    var all: [PackInfo] { builtIn + imported }

    let packsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Keytone/Packs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        refresh()
    }

    func pack(id: String) -> PackInfo? {
        all.first { $0.id == id }
    }

    func refresh() {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: packsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
        imported = folders
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { folder in
                PackInfo(
                    id: "pack:" + folder.lastPathComponent,
                    name: PackLoader.displayName(for: folder),
                    subtitle: FileManager.default.fileExists(atPath: folder.appendingPathComponent("config.json").path) ? "Pack de Mechvibes" : "Carpeta de audios",
                    category: .custom,
                    folder: folder
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Genera o carga el banco de sonidos. Pensado para llamarse fuera del hilo principal.
    func bank(for pack: PackInfo) throws -> SoundBank {
        cacheLock.lock()
        if let cached = cache[pack.id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let bank: SoundBank
        if let folder = pack.folder {
            bank = try PackLoader.load(folder: folder)
        } else {
            bank = SwitchSynth.makeBank(for: SwitchProfile.named(pack.id) ?? SwitchProfile.all[0])
        }

        cacheLock.lock()
        cache[pack.id] = bank
        cacheLock.unlock()
        return bank
    }

    /// Copia una carpeta de sonidos a la biblioteca y devuelve el pack resultante.
    func importPack(from source: URL) throws -> PackInfo {
        // Validamos antes de copiar para dar un error claro.
        _ = try PackLoader.load(folder: source)

        var destination = packsDirectory.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = packsDirectory.appendingPathComponent("\(source.lastPathComponent) \(suffix)", isDirectory: true)
            suffix += 1
        }
        try FileManager.default.copyItem(at: source, to: destination)
        refresh()
        guard let pack = imported.first(where: { $0.folder?.standardizedFileURL == destination.standardizedFileURL }) else {
            throw PackError.invalid("No se pudo registrar el pack importado.")
        }
        return pack
    }

    func remove(_ pack: PackInfo) {
        guard let folder = pack.folder else { return }
        try? FileManager.default.trashItem(at: folder, resultingItemURL: nil)
        cacheLock.lock()
        cache[pack.id] = nil
        cacheLock.unlock()
        refresh()
    }

    func revealPacksFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([packsDirectory])
    }
}
