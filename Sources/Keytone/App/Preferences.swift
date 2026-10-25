import Foundation

/// Ajustes persistentes del usuario (UserDefaults).
final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Key.enabled) } }
    @Published var volume: Double { didSet { defaults.set(volume, forKey: Key.volume) } }
    @Published var packID: String { didSet { defaults.set(packID, forKey: Key.packID) } }
    @Published var keyUpSounds: Bool { didSet { defaults.set(keyUpSounds, forKey: Key.keyUpSounds) } }
    @Published var mouseSounds: Bool { didSet { defaults.set(mouseSounds, forKey: Key.mouseSounds) } }
    @Published var repeatSounds: Bool { didSet { defaults.set(repeatSounds, forKey: Key.repeatSounds) } }
    @Published var dynamics: Bool { didSet { defaults.set(dynamics, forKey: Key.dynamics) } }
    @Published var stereoWidth: Double { didSet { defaults.set(stereoWidth, forKey: Key.stereoWidth) } }
    @Published var pitchVariation: Double { didSet { defaults.set(pitchVariation, forKey: Key.pitchVariation) } }
    @Published var volumeVariation: Double { didSet { defaults.set(volumeVariation, forKey: Key.volumeVariation) } }
    @Published var hotkeyEnabled: Bool { didSet { defaults.set(hotkeyEnabled, forKey: Key.hotkeyEnabled) } }
    @Published var excludedApps: [String] { didSet { defaults.set(excludedApps, forKey: Key.excludedApps) } }
    @Published var completedOnboarding: Bool { didSet { defaults.set(completedOnboarding, forKey: Key.completedOnboarding) } }

    private enum Key {
        static let enabled = "enabled"
        static let volume = "volume"
        static let packID = "packID"
        static let keyUpSounds = "keyUpSounds"
        static let mouseSounds = "mouseSounds"
        static let repeatSounds = "repeatSounds"
        static let dynamics = "dynamics"
        static let stereoWidth = "stereoWidth"
        static let pitchVariation = "pitchVariation"
        static let volumeVariation = "volumeVariation"
        static let hotkeyEnabled = "hotkeyEnabled"
        static let excludedApps = "excludedApps"
        static let completedOnboarding = "completedOnboarding"
    }

    init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.volume: 0.7,
            Key.packID: PackLibrary.defaultID,
            Key.keyUpSounds: true,
            Key.mouseSounds: false,
            Key.repeatSounds: false,
            Key.dynamics: true,
            Key.stereoWidth: 0.6,
            Key.pitchVariation: 0.4,
            Key.volumeVariation: 0.3,
            Key.hotkeyEnabled: true,
            Key.excludedApps: [String](),
            Key.completedOnboarding: false,
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        volume = defaults.double(forKey: Key.volume)
        packID = defaults.string(forKey: Key.packID) ?? PackLibrary.defaultID
        keyUpSounds = defaults.bool(forKey: Key.keyUpSounds)
        mouseSounds = defaults.bool(forKey: Key.mouseSounds)
        repeatSounds = defaults.bool(forKey: Key.repeatSounds)
        dynamics = defaults.bool(forKey: Key.dynamics)
        stereoWidth = defaults.double(forKey: Key.stereoWidth)
        pitchVariation = defaults.double(forKey: Key.pitchVariation)
        volumeVariation = defaults.double(forKey: Key.volumeVariation)
        hotkeyEnabled = defaults.bool(forKey: Key.hotkeyEnabled)
        excludedApps = defaults.stringArray(forKey: Key.excludedApps) ?? []
        completedOnboarding = defaults.bool(forKey: Key.completedOnboarding)
    }
}
