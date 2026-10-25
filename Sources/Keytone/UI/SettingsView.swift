import AppKit
import KeytoneCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct SettingsView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch state.settingsSection {
                case .welcome: WelcomePane()
                case .general: GeneralPane()
                case .sounds: SoundsPane()
                case .apps: AppsPane()
                case .about: AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 780, height: 540)
        .tint(Theme.accent)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                KeytoneLogo(size: 28)
                Text("Keytone")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.top, 34)
            .padding(.bottom, 18)

            item(.welcome, "Bienvenida", "hand.wave")
            item(.general, "General", "slider.horizontal.3")
            item(.sounds, "Sonidos", "waveform")
            item(.apps, "Apps", "app.badge")
            item(.about, "Acerca de", "info.circle")
            Spacer()
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(10)
        }
        .padding(.horizontal, 10)
        .frame(width: 190)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func item(_ section: SettingsSection, _ title: String, _ symbol: String) -> some View {
        let active = state.settingsSection == section
        return Button {
            state.settingsSection = section
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)
                Text(title).font(.system(size: 12.5, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(active ? Theme.accentSoft : .clear))
            .foregroundStyle(active ? Theme.accent : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bienvenida

@MainActor
private struct WelcomePane: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var prefs = AppState.shared.prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                KeytoneLogo(size: 54)
                Text("Tu Mac, con alma de teclado mecánico")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Cada tecla que pulses sonará como un interruptor de verdad, con variaciones naturales y sonido estéreo según su posición.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            step(1, "Concede «Monitorización de entrada»",
                 "macOS lo exige para que una app oiga el teclado. Keytone solo escucha qué tecla suena: no registra ni envía lo que escribes.",
                 done: state.hasPermission) {
                HStack {
                    Button("Abrir Ajustes del Sistema") { state.requestPermission() }
                        .buttonStyle(.borderedProminent)
                    Button("Reiniciar Keytone") { state.relaunch() }
                        .help("Si ya diste el permiso y no suena, reinicia la app.")
                }
                .controlSize(.small)
            }

            step(2, "Elige tu interruptor",
                 "Ahora mismo: \(state.currentPack?.name ?? "—"). Tienes 18 de serie y puedes importar packs de Mechvibes.",
                 done: prefs.completedOnboarding) {
                Button("Ver sonidos") { state.settingsSection = .sounds }
                    .controlSize(.small)
            }

            step(3, "Silencia cuando quieras",
                 "Pulsa \(AppState.hotkeyLabel) en cualquier app, o usa el icono de la barra de menús.",
                 done: prefs.completedOnboarding) {
                EmptyView()
            }

            Spacer()
            HStack {
                Spacer()
                Button {
                    prefs.completedOnboarding = true
                    state.settingsSection = .general
                    state.preview()
                } label: {
                    Text("Empezar a teclear").padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(32)
    }

    private func step<Extra: View>(_ number: Int, _ title: String, _ detail: String, done: Bool, @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(done ? Color.green.opacity(0.18) : Theme.accentSoft)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.green)
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
            }
        }
    }
}

// MARK: - General

@MainActor
private struct GeneralPane: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var prefs = AppState.shared.prefs

    var body: some View {
        Form {
            Section {
                Toggle("Sonidos activados", isOn: $prefs.enabled)
                Toggle("Abrir al iniciar sesión", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.launchAtLogin = $0 }
                ))
                Toggle("Atajo \(AppState.hotkeyLabel) para silenciar", isOn: $prefs.hotkeyEnabled)
            } header: {
                Text("General")
            }

            Section {
                Toggle("Sonido al soltar la tecla", isOn: $prefs.keyUpSounds)
                Toggle("Sonar al mantener pulsada (repetición)", isOn: $prefs.repeatSounds)
                Toggle("Clics del ratón", isOn: $prefs.mouseSounds)
                Toggle(isOn: $prefs.dynamics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dinámica realista")
                        Text("Al escribir rápido las teclas suenan más suaves, como cuando los dedos apenas rozan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Qué suena")
            }

            Section {
                HStack {
                    Image(systemName: state.hasPermission ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(state.hasPermission ? Color.green : Color.orange)
                    Text(state.hasPermission ? "Monitorización de entrada concedida" : "Falta el permiso de Monitorización de entrada")
                    Spacer()
                    if !state.hasPermission {
                        Button("Conceder") { state.requestPermission() }
                    }
                }
            } header: {
                Text("Permisos")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sonidos

@MainActor
private struct SoundsPane: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var prefs = AppState.shared.prefs
    @ObservedObject private var library = AppState.shared.library

    @State private var testText = ""
    @State private var packToDelete: PackInfo?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Interruptores de serie", detail: "Sintetizados en tiempo real a partir de la física de cada interruptor.")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(library.builtIn) { pack in
                            PackKeycap(pack: pack, selected: prefs.packID == pack.id, loading: state.isLoadingPack) {
                                state.select(pack)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom) {
                        sectionTitle("Mis packs", detail: "Importa packs de Mechvibes (carpeta con config.json) o una carpeta con tus propios audios.")
                        Spacer()
                        Button {
                            library.revealPacksFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Abrir carpeta de packs")
                        Button("Importar…", action: importPack)
                            .buttonStyle(.borderedProminent)
                    }
                    if let error = state.packError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    if library.imported.isEmpty {
                        emptyPacks
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(library.imported) { pack in
                                PackKeycap(pack: pack, selected: prefs.packID == pack.id, loading: state.isLoadingPack) {
                                    state.select(pack)
                                }
                                .contextMenu {
                                    Button("Mostrar en Finder") {
                                        if let folder = pack.folder { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                                    }
                                    Button("Eliminar pack", role: .destructive) { packToDelete = pack }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Ajuste fino", detail: nil)
                    slider("Volumen", value: $prefs.volume, symbol: "speaker.wave.2")
                    slider("Variación de tono", value: $prefs.pitchVariation, symbol: "tuningfork")
                    slider("Variación de fuerza", value: $prefs.volumeVariation, symbol: "hand.tap")
                    slider("Amplitud estéreo", value: $prefs.stereoWidth, symbol: "headphones")
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Prueba", detail: nil)
                    TextField("Escribe aquí para probar el sonido…", text: $testText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            .padding(28)
        }
        .alert("¿Eliminar «\(packToDelete?.name ?? "")»?", isPresented: Binding(
            get: { packToDelete != nil },
            set: { if !$0 { packToDelete = nil } }
        )) {
            Button("Eliminar", role: .destructive) {
                if let pack = packToDelete { state.remove(pack) }
                packToDelete = nil
            }
            Button("Cancelar", role: .cancel) { packToDelete = nil }
        } message: {
            Text("La carpeta se moverá a la papelera.")
        }
    }

    private var emptyPacks: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Aún no has importado ningún pack").font(.system(size: 12.5, weight: .semibold))
                Text("Hay cientos de packs gratuitos grabados de teclados reales en la comunidad de Mechvibes. Descomprime uno y pulsa «Importar…».")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    private func sectionTitle(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            if let detail {
                Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(title)
                .frame(width: 140, alignment: .leading)
            Slider(value: value, in: 0...1)
            Text("\(Int(value.wrappedValue * 100)) %")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .font(.system(size: 12.5))
    }

    private func importPack() {
        let panel = NSOpenPanel()
        panel.title = "Importar pack de sonidos"
        panel.message = "Elige la carpeta del pack (Mechvibes con config.json, o una carpeta con audios)."
        panel.prompt = "Importar"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { state.importPack(from: url) }
    }
}

// MARK: - Apps

@MainActor
private struct AppsPane: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var prefs = AppState.shared.prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apps en silencio").font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Keytone no sonará mientras estas apps estén en primer plano. Ideal para videollamadas, juegos o editar audio.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            List {
                if prefs.excludedApps.isEmpty {
                    Text("Ninguna app silenciada")
                        .foregroundStyle(.secondary)
                }
                ForEach(prefs.excludedApps, id: \.self) { bundleID in
                    HStack(spacing: 10) {
                        Image(nsImage: icon(for: bundleID))
                            .resizable()
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name(for: bundleID))
                            Text(bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            state.toggleExclusion(bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Button("Añadir app…", action: addApp)
                Spacer()
                Text("Sugerencias:").foregroundStyle(.secondary).font(.caption)
                ForEach(suggestions) { suggestion in
                    Button(suggestion.name) { state.toggleExclusion(suggestion.id) }
                        .controlSize(.small)
                        .disabled(prefs.excludedApps.contains(suggestion.id))
                }
            }
        }
        .padding(28)
    }

    private struct Suggestion: Identifiable {
        let id: String
        let name: String
    }

    private var suggestions: [Suggestion] {
        [
            Suggestion(id: "us.zoom.xos", name: "Zoom"),
            Suggestion(id: "com.microsoft.teams2", name: "Teams"),
            Suggestion(id: "com.apple.FaceTime", name: "FaceTime"),
            Suggestion(id: "com.hnc.Discord", name: "Discord"),
        ]
        .filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.id) != nil }
    }

    private func icon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
    }

    private func name(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Silenciar Keytone en…"
        panel.prompt = "Añadir"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !prefs.excludedApps.contains(id) {
                prefs.excludedApps.append(id)
            }
        }
    }
}

// MARK: - Acerca de

@MainActor
private struct AboutPane: View {
    @ObservedObject private var stats = AppState.shared.stats

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            KeytoneLogo(size: 72)
            Text("Keytone").font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Sonidos de teclado mecánico para macOS")
                .foregroundStyle(.secondary)
            HStack(spacing: 28) {
                VStack {
                    Text(stats.today.formatted()).font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("teclas hoy").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text(stats.total.formatted()).font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("teclas en total").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            Spacer()
            Text("Keytone no guarda ni envía lo que escribes: solo cuenta pulsaciones en tu Mac.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}
