import Foundation

/// Modo resonante de la carcasa/placa: una sinusoide amortiguada.
public struct Resonance: Sendable {
    public var frequency: Float
    public var decay: Float
    public var amplitude: Float

    public init(_ frequency: Float, _ decay: Float, _ amplitude: Float) {
        self.frequency = frequency
        self.decay = decay
        self.amplitude = amplitude
    }
}

public enum SwitchCategory: String, CaseIterable, Sendable {
    case clicky = "Clicky"
    case tactile = "Táctil"
    case linear = "Lineal"
    case vintage = "Vintage"
    case fun = "Divertido"
    case custom = "Importado"
}

/// Tipos de síntesis especiales que no siguen el modelo de interruptor mecánico.
public enum SynthStyle: Sendable {
    case mechanical
    case typewriter
    case bubble
    case chiptune
}

/// Parámetros físicos que describen cómo suena un interruptor.
public struct SwitchProfile: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var category: SwitchCategory
    public var style: SynthStyle = .mechanical

    /// Clic agudo de la pieza "click jacket" (0 = no hay clic).
    public var click: Float = 0
    public var clickFrequency: Float = 4500
    /// Golpe táctil a mitad de recorrido.
    public var tactile: Float = 0
    /// Tiempo entre el inicio de la pulsación y el fondo (ms).
    public var travel: Float = 8
    /// Resonancias del golpe contra el fondo.
    public var resonances: [Resonance] = []
    /// Ruido de impacto (plástico contra plástico).
    public var impactNoise: Float = 0.4
    public var noiseCutoff: Float = 5000
    public var noiseDecay: Float = 0.004
    /// "Ping" metálico del muelle.
    public var spring: Float = 0.03
    public var springFrequency: Float = 4200
    public var springDecay: Float = 0.05
    /// Nivel relativo y brillo del sonido al soltar la tecla.
    public var releaseLevel: Float = 0.45
    public var releaseClick: Float = 0
    public var releaseBrightness: Float = 1.2
    /// Volumen general del perfil.
    public var gain: Float = 0.9

    public init(id: String, name: String, subtitle: String, category: SwitchCategory) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.category = category
    }

    func with(_ change: (inout SwitchProfile) -> Void) -> SwitchProfile {
        var copy = self
        change(&copy)
        return copy
    }
}

public extension SwitchProfile {
    static func named(_ id: String) -> SwitchProfile? {
        all.first { $0.id == id }
    }

    static let all: [SwitchProfile] = [
        SwitchProfile(id: "mx-blue", name: "MX Blue", subtitle: "Clic clásico y nítido", category: .clicky).with {
            $0.click = 1.0; $0.clickFrequency = 4600; $0.tactile = 0.2; $0.travel = 9
            $0.resonances = [Resonance(1450, 0.012, 1), Resonance(2650, 0.008, 0.6), Resonance(520, 0.018, 0.5)]
            $0.impactNoise = 0.5; $0.noiseCutoff = 6000
            $0.spring = 0.05; $0.springFrequency = 4300
            $0.releaseLevel = 0.6; $0.releaseClick = 0.6; $0.releaseBrightness = 1.15
        },
        SwitchProfile(id: "box-jade", name: "Box Jade", subtitle: "Clic grueso y contundente", category: .clicky).with {
            $0.click = 1.35; $0.clickFrequency = 5400; $0.tactile = 0.3; $0.travel = 8
            $0.resonances = [Resonance(1800, 0.010, 1), Resonance(3200, 0.006, 0.5), Resonance(620, 0.015, 0.45)]
            $0.impactNoise = 0.55; $0.noiseCutoff = 7500
            $0.spring = 0.04
            $0.releaseLevel = 0.7; $0.releaseClick = 1.0; $0.releaseBrightness = 1.1
        },
        SwitchProfile(id: "alps-blue", name: "Alps Blue", subtitle: "Clic vintage áspero", category: .clicky).with {
            $0.click = 0.9; $0.clickFrequency = 3800; $0.tactile = 0.5; $0.travel = 10
            $0.resonances = [Resonance(1600, 0.012, 1), Resonance(2900, 0.008, 0.6), Resonance(700, 0.016, 0.5)]
            $0.impactNoise = 0.6; $0.noiseCutoff = 6500
            $0.spring = 0.06; $0.springFrequency = 3900
            $0.releaseLevel = 0.6; $0.releaseClick = 0.5
        },
        SwitchProfile(id: "mx-brown", name: "MX Brown", subtitle: "Táctil, discreto", category: .tactile).with {
            $0.tactile = 0.5; $0.travel = 7
            $0.resonances = [Resonance(1100, 0.014, 1), Resonance(2200, 0.008, 0.5), Resonance(420, 0.02, 0.6)]
            $0.impactNoise = 0.4; $0.noiseCutoff = 4500
            $0.spring = 0.04
            $0.releaseLevel = 0.4
        },
        SwitchProfile(id: "holy-panda", name: "Holy Panda", subtitle: "Bache marcado y thock", category: .tactile).with {
            $0.tactile = 0.8; $0.travel = 9
            $0.resonances = [Resonance(520, 0.025, 1), Resonance(1150, 0.012, 0.5), Resonance(240, 0.035, 0.9)]
            $0.impactNoise = 0.3; $0.noiseCutoff = 3500
            $0.spring = 0.02
            $0.releaseLevel = 0.5; $0.releaseBrightness = 1.3
        },
        SwitchProfile(id: "topre", name: "Topre", subtitle: "Capacitivo, thock suave", category: .tactile).with {
            $0.tactile = 0.3; $0.travel = 6
            $0.resonances = [Resonance(420, 0.03, 1), Resonance(880, 0.015, 0.5), Resonance(200, 0.04, 0.8)]
            $0.impactNoise = 0.35; $0.noiseCutoff = 2500
            $0.spring = 0
            $0.releaseLevel = 0.55; $0.releaseBrightness = 1.1
        },
        SwitchProfile(id: "mx-red", name: "MX Red", subtitle: "Lineal y ligero", category: .linear).with {
            $0.travel = 7
            $0.resonances = [Resonance(1200, 0.012, 1), Resonance(2400, 0.007, 0.5), Resonance(450, 0.02, 0.6)]
            $0.impactNoise = 0.45; $0.noiseCutoff = 5000
            $0.releaseLevel = 0.45
        },
        SwitchProfile(id: "mx-black", name: "MX Black", subtitle: "Lineal pesado y profundo", category: .linear).with {
            $0.travel = 9
            $0.resonances = [Resonance(900, 0.016, 1), Resonance(1800, 0.009, 0.5), Resonance(360, 0.025, 0.7)]
            $0.impactNoise = 0.4; $0.noiseCutoff = 4200
            $0.spring = 0.08; $0.springFrequency = 3800
            $0.releaseLevel = 0.5
        },
        SwitchProfile(id: "gateron-yellow", name: "Gateron Yellow", subtitle: "Lubricado y cremoso", category: .linear).with {
            $0.travel = 8
            $0.resonances = [Resonance(650, 0.02, 1), Resonance(1300, 0.01, 0.4), Resonance(300, 0.03, 0.8)]
            $0.impactNoise = 0.25; $0.noiseCutoff = 3000
            $0.spring = 0.01
            $0.releaseLevel = 0.35
        },
        SwitchProfile(id: "cream", name: "NK Cream", subtitle: "POM, clack brillante", category: .linear).with {
            $0.travel = 7
            $0.resonances = [Resonance(1500, 0.012, 1), Resonance(3000, 0.006, 0.4), Resonance(600, 0.018, 0.4)]
            $0.impactNoise = 0.5; $0.noiseCutoff = 8000
            $0.releaseLevel = 0.6; $0.releaseBrightness = 1.2
        },
        SwitchProfile(id: "alu-thock", name: "Aluminio Thock", subtitle: "Custom de gama alta", category: .linear).with {
            $0.travel = 9
            $0.resonances = [Resonance(380, 0.035, 1), Resonance(760, 0.02, 0.5), Resonance(170, 0.05, 0.9)]
            $0.impactNoise = 0.2; $0.noiseCutoff = 2200
            $0.spring = 0
            $0.releaseLevel = 0.3
        },
        SwitchProfile(id: "marble", name: "Mármol", subtitle: "Marbly y lofi", category: .linear).with {
            $0.travel = 6
            $0.resonances = [Resonance(2300, 0.02, 1), Resonance(4100, 0.012, 0.6), Resonance(900, 0.02, 0.3)]
            $0.impactNoise = 0.35; $0.noiseCutoff = 9000
            $0.releaseLevel = 0.5; $0.releaseBrightness = 1.1
        },
        SwitchProfile(id: "silent", name: "Silent Alpaca", subtitle: "Amortiguado, para la oficina", category: .linear).with {
            $0.travel = 7
            $0.resonances = [Resonance(500, 0.01, 1), Resonance(900, 0.006, 0.3)]
            $0.impactNoise = 0.15; $0.noiseCutoff = 1500
            $0.spring = 0
            $0.releaseLevel = 0.2; $0.gain = 0.55
        },
        SwitchProfile(id: "laptop", name: "Portátil", subtitle: "Tijera de bajo perfil", category: .linear).with {
            $0.travel = 3
            $0.resonances = [Resonance(2600, 0.005, 1), Resonance(4200, 0.003, 0.5), Resonance(900, 0.007, 0.4)]
            $0.impactNoise = 0.6; $0.noiseCutoff = 9000; $0.noiseDecay = 0.002
            $0.spring = 0
            $0.releaseLevel = 0.35; $0.gain = 0.75
        },
        SwitchProfile(id: "model-m", name: "Model M", subtitle: "Buckling spring de IBM", category: .vintage).with {
            $0.click = 1.2; $0.clickFrequency = 3200; $0.travel = 6
            $0.resonances = [Resonance(950, 0.02, 1), Resonance(2100, 0.012, 0.6), Resonance(420, 0.03, 0.7)]
            $0.impactNoise = 0.6; $0.noiseCutoff = 7000
            $0.spring = 0.5; $0.springFrequency = 2900; $0.springDecay = 0.09
            $0.releaseLevel = 0.7; $0.releaseClick = 0.8
        },
        SwitchProfile(id: "typewriter", name: "Máquina de escribir", subtitle: "Golpe, carro y campanita", category: .vintage).with {
            $0.style = .typewriter; $0.travel = 14
            $0.resonances = [Resonance(1250, 0.04, 1), Resonance(2350, 0.03, 0.7), Resonance(3700, 0.02, 0.5), Resonance(130, 0.03, 0.9)]
            $0.impactNoise = 0.9; $0.noiseCutoff = 6000; $0.noiseDecay = 0.006
            $0.spring = 0.15; $0.springFrequency = 3100; $0.springDecay = 0.07
            $0.releaseLevel = 0.3
        },
        SwitchProfile(id: "bubble", name: "Burbujas", subtitle: "Pop relajante", category: .fun).with {
            $0.style = .bubble
            $0.releaseLevel = 0.35; $0.gain = 0.7
        },
        SwitchProfile(id: "chiptune", name: "Arcade 8-bit", subtitle: "Cada tecla, una nota", category: .fun).with {
            $0.style = .chiptune
            $0.releaseLevel = 0; $0.gain = 0.45
        },
    ]
}
