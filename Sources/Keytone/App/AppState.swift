import AppKit
import Combine
import KeytoneCore
import ServiceManagement

struct RunningAppRef: Equatable {
    let name: String
    let bundleID: String
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case welcome, general, sounds, apps, about
    var id: String { rawValue }
}

/// Coordinador de la app: une la captura de teclas, los packs y el audio.
final class AppState: ObservableObject {
    static let shared = AppState()

    let prefs = Preferences()
    let library = PackLibrary()
    let stats = TypingStats()

    @Published private(set) var hasPermission = InputMonitor.hasPermission
    @Published private(set) var isLoadingPack = false
    @Published private(set) var lastExternalApp: RunningAppRef?
    @Published var packError: String?
    @Published var settingsSection: SettingsSection = .general

    private let audio = AudioEngine()
    private let monitor = InputMonitor()
    private var bank: SoundBank?
    private var lastPressTime: TimeInterval = 0
    private var permissionTimer: Timer?
    private var previewOnLoad = false
    private var subscriptions = Set<AnyCancellable>()
    private var started = false
    private var workspaceObserver: NSObjectProtocol?

    /// Atajo global para silenciar: ⌥⇧⌘K.
    static let hotkeyCode: UInt16 = 40
    static let hotkeyLabel = "⌥⇧⌘K"

    var currentPack: PackInfo? { library.pack(id: prefs.packID) }

    func start() {
        guard !started else { return }
        started = true

        monitor.handler = { [weak self] event in self?.handle(event) }

        prefs.$packID
            .removeDuplicates()
            .sink { [weak self] id in self?.loadPack(id: id) }
            .store(in: &subscriptions)

        prefs.$enabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled { self?.audio.start() } else { self?.audio.stop() }
            }
            .store(in: &subscriptions)

        // Reenviamos los cambios de ajustes para que las vistas que observan AppState se refresquen.
        prefs.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &subscriptions)

        trackFrontmostApp()
        startMonitoring(requestIfNeeded: false)
    }

    // MARK: - Permisos

    func requestPermission() {
        InputMonitor.requestPermission()
        InputMonitor.openPrivacySettings()
        startMonitoring(requestIfNeeded: false)
    }

    private func startMonitoring(requestIfNeeded: Bool) {
        if monitor.start() {
            hasPermission = true
            permissionTimer?.invalidate()
            permissionTimer = nil
            return
        }
        hasPermission = false
        if requestIfNeeded { InputMonitor.requestPermission() }
        guard permissionTimer == nil else { return }
        // Reintentamos hasta que el usuario conceda el permiso en Ajustes del Sistema.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.monitor.start() {
                self.hasPermission = true
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
            }
        }
    }

    func relaunch() {
        stats.save()
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.6; open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Packs

    func select(_ pack: PackInfo) {
        previewOnLoad = true
        if prefs.packID == pack.id {
            previewOnLoad = false
            preview()
        } else {
            prefs.packID = pack.id
        }
    }

    private func loadPack(id: String) {
        guard let pack = library.pack(id: id) ?? library.pack(id: PackLibrary.defaultID) else { return }
        if pack.id != id {
            prefs.packID = pack.id
            return
        }
        isLoadingPack = true
        packError = nil
        let library = self.library
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try library.bank(for: pack) }
            DispatchQueue.main.async {
                guard let self, self.prefs.packID == pack.id else { return }
                self.isLoadingPack = false
                switch result {
                case .success(let bank):
                    self.bank = bank
                    if self.previewOnLoad { self.preview() }
                case .failure(let error):
                    self.packError = error.localizedDescription
                }
                self.previewOnLoad = false
            }
        }
    }

    func importPack(from url: URL) {
        do {
            let pack = try library.importPack(from: url)
            packError = nil
            select(pack)
        } catch {
            packError = error.localizedDescription
        }
    }

    func remove(_ pack: PackInfo) {
        if prefs.packID == pack.id { prefs.packID = PackLibrary.defaultID }
        library.remove(pack)
    }

    /// Toca una frase corta para escuchar el pack elegido.
    func preview() {
        // "hola keytone⏎" con ritmo humano.
        let sequence: [UInt16] = [4, 31, 37, 0, 49, 40, 14, 16, 17, 31, 45, 14, 36]
        var time: TimeInterval = 0
        for code in sequence {
            let hold = Double.random(in: 0.05...0.09)
            DispatchQueue.main.asyncAfter(deadline: .now() + time) { [weak self] in
                self?.play(keyCode: code, kind: KeyLayout.kind(for: code), phase: .press, isRepeat: false, force: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + time + hold) { [weak self] in
                self?.play(keyCode: code, kind: KeyLayout.kind(for: code), phase: .release, isRepeat: false, force: true)
            }
            time += code == 49 ? 0.2 : Double.random(in: 0.09...0.16)
        }
    }

    // MARK: - Apps excluidas

    private func trackFrontmostApp() {
        updateExternalApp(NSWorkspace.shared.frontmostApplication)
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.updateExternalApp(app)
        }
    }

    private func updateExternalApp(_ app: NSRunningApplication?) {
        guard let app, let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        lastExternalApp = RunningAppRef(name: app.localizedName ?? id, bundleID: id)
    }

    func isExcluded(_ bundleID: String) -> Bool {
        prefs.excludedApps.contains(bundleID)
    }

    func toggleExclusion(_ bundleID: String) {
        if let index = prefs.excludedApps.firstIndex(of: bundleID) {
            prefs.excludedApps.remove(at: index)
        } else {
            prefs.excludedApps.append(bundleID)
        }
    }

    // MARK: - Inicio de sesión

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Keytone: no se pudo cambiar el inicio de sesión: \(error)")
            }
            objectWillChange.send()
        }
    }

    // MARK: - Teclas

    private func handle(_ event: InputEvent) {
        if prefs.hotkeyEnabled, event.phase == .press, !event.isRepeat, event.keyCode == Self.hotkeyCode,
           event.flags.contains([.maskCommand, .maskAlternate, .maskShift]), !event.flags.contains(.maskControl) {
            prefs.enabled.toggle()
            return
        }

        if event.phase == .press, !event.isRepeat, event.kind != .mouse, event.kind != .modifier {
            stats.record()
        }

        guard prefs.enabled else { return }
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, isExcluded(front) { return }
        play(keyCode: event.keyCode, kind: event.kind, phase: event.phase, isRepeat: event.isRepeat, force: false)
    }

    private func play(keyCode: UInt16, kind: KeyKind, phase: KeyPhase, isRepeat: Bool, force: Bool) {
        guard let bank else { return }
        if !force {
            if isRepeat && !prefs.repeatSounds { return }
            if kind == .mouse && !prefs.mouseSounds { return }
            if phase == .release && !prefs.keyUpSounds { return }
        }

        let sample: [Float]?
        if kind == .mouse && !bank.hasSamples(kind: .mouse, phase: phase) {
            sample = SwitchSynth.mouseBank.sample(keyCode: keyCode, kind: .mouse, phase: phase)
        } else {
            sample = bank.sample(keyCode: keyCode, kind: kind, phase: phase)
        }
        guard let sample else { return }

        // Curva perceptiva: el control de volumen se siente lineal.
        var volume = Float(prefs.volume * prefs.volume)

        // Dinámica: al escribir rápido los dedos golpean más suave, como en un teclado real.
        if prefs.dynamics, phase == .press, kind != .mouse {
            let now = ProcessInfo.processInfo.systemUptime
            let gap = now - lastPressTime
            lastPressTime = now
            if gap < 0.09 { volume *= 0.8 + 0.2 * Float(gap / 0.09) }
        }
        if isRepeat { volume *= 0.7 }
        volume *= 1 + Float.random(in: -1...1) * 0.25 * Float(prefs.volumeVariation)

        let rate = 1 + Float.random(in: -1...1) * 0.06 * Float(prefs.pitchVariation)
        let position = kind == .mouse ? 0.75 : KeyLayout.horizontalPosition(for: keyCode)
        let pan = (position * 2 - 1) * Float(prefs.stereoWidth) * 0.8

        audio.play(sample, volume: volume, pan: pan, rate: rate)
    }
}
