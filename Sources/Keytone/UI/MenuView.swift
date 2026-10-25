import KeytoneCore
import SwiftUI

/// Panel que se abre desde la barra de menús.
@MainActor
struct MenuView: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var prefs = AppState.shared.prefs
    @ObservedObject private var library = AppState.shared.library
    @ObservedObject private var stats = AppState.shared.stats

    @State private var filter: SwitchCategory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !state.hasPermission { permissionBanner }
            nowPlaying
            categoryFilter
            packGrid
            volumeRow
            HStack(spacing: 6) {
                ChipToggle(title: "Al soltar", symbol: "arrow.up.square", isOn: $prefs.keyUpSounds)
                ChipToggle(title: "Ratón", symbol: "computermouse", isOn: $prefs.mouseSounds)
                ChipToggle(title: "Dinámica", symbol: "waveform", isOn: $prefs.dynamics)
            }
            statsRow
            Divider().opacity(0.5)
            footer
        }
        .padding(16)
        .frame(width: 348)
    }

    // MARK: - Secciones

    private var header: some View {
        HStack(spacing: 10) {
            KeytoneLogo(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Keytone")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(prefs.enabled ? "Sonando · \(AppState.hotkeyLabel) para silenciar" : "En silencio · \(AppState.hotkeyLabel) para activar")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PowerButton(isOn: $prefs.enabled)
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 6) {
                Text("Falta un permiso")
                    .font(.system(size: 12, weight: .semibold))
                Text("Keytone necesita «Monitorización de entrada» para oír tus teclas. No guarda ni envía nada de lo que escribes.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Conceder permiso") { state.requestPermission() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accentSoft))
    }

    private var nowPlaying: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.color(for: state.currentPack?.category ?? .clicky).opacity(0.18))
                Image(systemName: Theme.symbol(for: state.currentPack?.category ?? .clicky))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color(for: state.currentPack?.category ?? .clicky))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.currentPack?.name ?? "—")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(state.packError ?? state.currentPack?.subtitle ?? "")
                    .font(.system(size: 10.5))
                    .foregroundStyle(state.packError == nil ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                state.preview()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.accent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(KeycapButtonStyle())
            .help("Escuchar")
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                filterChip(nil, title: "Todos")
                ForEach(availableCategories, id: \.self) { category in
                    filterChip(category, title: category.rawValue)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func filterChip(_ category: SwitchCategory?, title: String) -> some View {
        let active = filter == category
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { filter = category }
        } label: {
            HStack(spacing: 4) {
                if let category {
                    Circle().fill(Theme.color(for: category)).frame(width: 6, height: 6)
                }
                Text(title).font(.system(size: 10.5, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(active ? Color.primary.opacity(0.14) : Color.primary.opacity(0.05)))
            .foregroundStyle(active ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private var availableCategories: [SwitchCategory] {
        SwitchCategory.allCases.filter { category in library.all.contains { $0.category == category } }
    }

    private var packGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(library.all.filter { filter == nil || $0.category == filter }) { pack in
                    PackKeycap(
                        pack: pack,
                        selected: prefs.packID == pack.id,
                        loading: state.isLoadingPack
                    ) {
                        state.select(pack)
                    }
                }
            }
            .padding(.horizontal, 1)
            .padding(.top, 1)
            .padding(.bottom, 4)
        }
        .scrollIndicators(.never)
        .frame(height: 214)
    }

    private var volumeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Slider(value: $prefs.volume, in: 0...1)
                .tint(Theme.accent)
                .controlSize(.small)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("\(Int(prefs.volume * 100))")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: stats.today.formatted(), label: "teclas hoy")
            Spacer()
            stat(value: "\(stats.wordsPerMinute)", label: "ppm ahora")
            Spacer()
            stat(value: stats.total.formatted(.number.notation(.compactName)), label: "en total")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if let app = state.lastExternalApp {
                let muted = state.isExcluded(app.bundleID)
                Button {
                    state.toggleExclusion(app.bundleID)
                } label: {
                    Label(muted ? "Activar en \(app.name)" : "Silenciar en \(app.name)",
                          systemImage: muted ? "speaker.wave.2" : "speaker.slash")
                        .lineLimit(1)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
            Spacer()
            Button {
                WindowManager.shared.showSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Ajustes")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Salir de Keytone")
        }
        .foregroundStyle(.secondary)
    }
}

/// Interruptor grande de encendido.
struct PowerButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Theme.accent : Color.primary.opacity(0.15))
                    .frame(width: 46, height: 26)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .frame(width: 22, height: 22)
                    .padding(2)
                    .overlay(
                        Image(systemName: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isOn ? Theme.accent : Color.gray)
                    )
            }
        }
        .buttonStyle(.plain)
        .help(isOn ? "Silenciar" : "Activar")
    }
}
