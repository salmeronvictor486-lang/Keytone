import KeytoneCore
import SwiftUI

enum Theme {
    /// Naranja "keycap" propio de Keytone.
    static let accent = Color(red: 1.0, green: 0.47, blue: 0.2)
    static let accentSoft = Color(red: 1.0, green: 0.47, blue: 0.2).opacity(0.16)

    /// Cada categoría usa el color típico del vástago del interruptor.
    static func color(for category: SwitchCategory) -> Color {
        switch category {
        case .clicky: return Color(red: 0.26, green: 0.55, blue: 1.0)
        case .tactile: return Color(red: 0.72, green: 0.48, blue: 0.3)
        case .linear: return Color(red: 0.95, green: 0.3, blue: 0.33)
        case .vintage: return Color(red: 0.85, green: 0.75, blue: 0.55)
        case .fun: return Color(red: 0.7, green: 0.45, blue: 1.0)
        case .custom: return Color(red: 0.3, green: 0.8, blue: 0.55)
        }
    }

    static func symbol(for category: SwitchCategory) -> String {
        switch category {
        case .clicky: return "waveform.path"
        case .tactile: return "hand.point.up.left"
        case .linear: return "arrow.down.to.line"
        case .vintage: return "clock.arrow.circlepath"
        case .fun: return "sparkles"
        case .custom: return "folder"
        }
    }
}

/// Fondo con forma de tecla: cara superior con brillo y "falda" inferior.
struct KeycapBackground: View {
    var tint: Color = .clear
    var selected = false
    var hovering = false
    var radius: CGFloat = 10

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(scheme == .dark ? 0.45 : 0.16))
                .offset(y: 2.5)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(scheme == .dark ? 0.09 : 0.7), Color.white.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                ))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(selected ? 0.14 : (hovering ? 0.07 : 0)))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(selected ? Theme.accent : Color.primary.opacity(hovering ? 0.18 : 0.09), lineWidth: selected ? 1.6 : 1)
        }
    }
}

struct KeycapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

/// Logotipo: una tecla con la "K".
struct KeytoneLogo: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color(red: 0.62, green: 0.24, blue: 0.08))
                .offset(y: size * 0.07)
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.32), Theme.accent], startPoint: .top, endPoint: .bottom))
            Text("K")
                .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

/// Tecla seleccionable que representa un pack de sonido.
struct PackKeycap: View {
    let pack: PackInfo
    let selected: Bool
    var loading = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.color(for: pack.category))
                        .frame(width: 7, height: 7)
                    Spacer(minLength: 0)
                    if selected {
                        if loading {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                Spacer(minLength: 0)
                Text(pack.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(pack.category.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(KeycapBackground(tint: Theme.color(for: pack.category), selected: selected, hovering: hovering))
            .contentShape(Rectangle())
        }
        .buttonStyle(KeycapButtonStyle())
        .onHover { hovering = $0 }
        .help(pack.subtitle)
    }
}

/// Pastilla de opción activable.
struct ChipToggle: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(isOn ? Theme.accentSoft : Color.primary.opacity(0.06))
            )
            .overlay(Capsule().strokeBorder(isOn ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1))
            .foregroundStyle(isOn ? Theme.accent : Color.primary.opacity(0.75))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
