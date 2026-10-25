import Foundation

/// Sintetizador procedural de interruptores mecánicos.
///
/// Cada sonido se construye como en un teclado real: clic de la pieza interna,
/// bache táctil, golpe contra el fondo (resonancias de carcasa + ruido de plástico),
/// vibración del estabilizador y "ping" del muelle. Con semillas distintas se generan
/// variaciones para que ninguna pulsación suene idéntica a la anterior.
public enum SwitchSynth {
    public static let sampleRate: Float = 48_000

    public static let pressVariants = 6
    public static let releaseVariants = 4

    /// Genera el banco completo de sonidos de un perfil.
    public static func makeBank(for profile: SwitchProfile) -> SoundBank {
        let bank = SoundBank(name: profile.name)
        for kind in KeyKind.allCases {
            for v in 0..<pressVariants {
                bank.add(render(profile, kind: kind, phase: .press, variant: v), kind: kind, phase: .press)
            }
            for v in 0..<releaseVariants {
                bank.add(render(profile, kind: kind, phase: .release, variant: v), kind: kind, phase: .release)
            }
        }
        return bank
    }

    /// Banco genérico de clics de ratón, usado cuando un pack no trae los suyos.
    public static let mouseBank: SoundBank = {
        let bank = SoundBank(name: "Ratón")
        for v in 0..<pressVariants {
            bank.add(renderMouse(phase: .press, variant: v), kind: .mouse, phase: .press)
            bank.add(renderMouse(phase: .release, variant: v), kind: .mouse, phase: .release)
        }
        return bank
    }()

    // MARK: - Forma según el tipo de tecla

    private struct KindShape {
        var frequency: Float
        var decay: Float
        var level: Float
        var rattle: Float
    }

    private static func shape(for kind: KeyKind) -> KindShape {
        switch kind {
        case .normal, .mouse: return KindShape(frequency: 1, decay: 1, level: 1, rattle: 0)
        case .space: return KindShape(frequency: 0.72, decay: 1.6, level: 1.12, rattle: 0.6)
        case .enter: return KindShape(frequency: 0.88, decay: 1.25, level: 1.08, rattle: 0.3)
        case .backspace: return KindShape(frequency: 0.9, decay: 1.15, level: 1.04, rattle: 0.15)
        case .modifier: return KindShape(frequency: 0.95, decay: 1, level: 0.85, rattle: 0)
        }
    }

    // MARK: - Render

    public static func render(_ p: SwitchProfile, kind: KeyKind, phase: KeyPhase, variant: Int) -> [Float] {
        if kind == .mouse { return renderMouse(phase: phase, variant: variant) }

        let level = phase == .press ? 1 : p.releaseLevel
        guard level > 0 else { return [] }

        var rng = SeededRandom(seed: seed(p.id, kind, phase, variant))
        let s = shape(for: kind)

        var out: [Float]
        switch (p.style, phase) {
        case (.mechanical, .press): out = mechanicalPress(p, s, &rng)
        case (.mechanical, .release): out = mechanicalRelease(p, s, &rng)
        case (.typewriter, .press): out = typewriterPress(p, s, kind: kind, &rng)
        case (.typewriter, .release): out = mechanicalRelease(p, s, &rng)
        case (.bubble, _): out = bubble(s, phase: phase, &rng)
        case (.chiptune, _): out = chiptune(kind: kind, variant: variant, &rng)
        }

        return finish(out, level: p.gain * s.level * level)
    }

    private static func finish(_ input: [Float], level: Float) -> [Float] {
        var out = input
        var hp = Biquad.highPass(35, sampleRate: sampleRate)
        hp.process(&out)
        DSP.normalize(&out, to: 1)
        // Saturación suave: compacta los picos como hace la carcasa real.
        let drive: Float = 1.6
        let norm = tanh(drive)
        for i in out.indices { out[i] = tanh(out[i] * drive) / norm }
        DSP.normalize(&out, to: min(0.98, level))
        DSP.trimTail(&out, sampleRate: sampleRate)
        return out
    }

    // MARK: - Interruptor mecánico

    private static func mechanicalPress(_ p: SwitchProfile, _ s: KindShape, _ rng: inout SeededRandom) -> [Float] {
        var out: [Float] = []
        let travel = p.travel / 1000 * rng.jitter(0.15)
        let bottom = samples(travel)

        if p.click > 0 {
            DSP.mix(click(p.clickFrequency * rng.jitter(0.06), &rng), into: &out, at: 0, gain: p.click)
        }
        if p.tactile > 0 {
            DSP.mix(tick(&rng), into: &out, at: samples(travel * 0.45), gain: p.tactile * 0.45)
        }
        DSP.mix(impact(p, freqScale: s.frequency, decayScale: s.decay, &rng), into: &out, at: bottom)
        if s.rattle > 0 {
            // Estabilizador: un segundo golpe pequeño y metálico.
            let rattle = impact(p, freqScale: s.frequency * 1.9, decayScale: 0.5, &rng)
            DSP.mix(rattle, into: &out, at: bottom + samples(0.004 * rng.jitter(0.3)), gain: s.rattle * 0.45)
        }
        if p.spring > 0 {
            DSP.mix(ping(p.springFrequency * rng.jitter(0.03), decay: p.springDecay, &rng), into: &out, at: bottom, gain: p.spring * 0.6)
        }
        return out
    }

    private static func mechanicalRelease(_ p: SwitchProfile, _ s: KindShape, _ rng: inout SeededRandom) -> [Float] {
        var out: [Float] = []
        var offset = 0
        if p.releaseClick > 0 {
            DSP.mix(click(p.clickFrequency * 1.1 * rng.jitter(0.06), &rng), into: &out, at: 0, gain: p.releaseClick * 0.8)
            offset = samples(0.002)
        }
        var up = p
        up.impactNoise *= 0.8
        up.noiseCutoff *= 1.2
        DSP.mix(impact(up, freqScale: s.frequency * p.releaseBrightness, decayScale: s.decay * 0.7, &rng), into: &out, at: offset)
        if s.rattle > 0 {
            let rattle = impact(p, freqScale: s.frequency * 2.1, decayScale: 0.4, &rng)
            DSP.mix(rattle, into: &out, at: offset + samples(0.003), gain: s.rattle * 0.35)
        }
        if p.spring > 0 {
            DSP.mix(ping(p.springFrequency * rng.jitter(0.03), decay: p.springDecay * 0.8, &rng), into: &out, at: offset, gain: p.spring * 0.5)
        }
        return out
    }

    // MARK: - Máquina de escribir

    private static func typewriterPress(_ p: SwitchProfile, _ s: KindShape, kind: KeyKind, _ rng: inout SeededRandom) -> [Float] {
        var out = mechanicalPress(p, s, &rng)
        guard kind == .enter else { return out }

        // Retorno de carro: trinquete y campanita.
        var t = samples(0.06)
        for i in 0..<8 {
            let gain = 0.35 * (1 - Float(i) * 0.08)
            DSP.mix(click(2400 * rng.jitter(0.1), &rng), into: &out, at: t, gain: gain)
            t += samples(0.022 * rng.jitter(0.15))
        }
        DSP.mix(bell(2350 * rng.jitter(0.01), &rng), into: &out, at: t, gain: 0.55)
        return out
    }

    private static func bell(_ f0: Float, _ rng: inout SeededRandom) -> [Float] {
        let partials: [Resonance] = [Resonance(1, 1.2, 1), Resonance(2.76, 0.5, 0.5), Resonance(5.4, 0.25, 0.3), Resonance(8.93, 0.12, 0.15)]
        let n = samples(1.6)
        var out = [Float](repeating: 0, count: n)
        for partial in partials {
            let f = f0 * partial.frequency
            let w = 2 * Float.pi * f / sampleRate
            let phase = rng.unit() * 2 * .pi
            for i in 0..<n {
                let t = Float(i) / sampleRate
                out[i] += partial.amplitude * exp(-t / partial.decay) * sin(w * Float(i) + phase) * min(1, t / 0.0008)
            }
        }
        DSP.normalize(&out, to: 1)
        return out
    }

    // MARK: - Divertidos

    private static func bubble(_ s: KindShape, phase: KeyPhase, _ rng: inout SeededRandom) -> [Float] {
        let isPress = phase == .press
        let f0 = (isPress ? 620 : 1050) * s.frequency * rng.jitter(0.18)
        let tau: Float = (isPress ? 0.028 : 0.012) * s.decay
        let rise: Float = isPress ? 0.9 : 0.5
        let n = samples(tau * 6)
        var out = [Float](repeating: 0, count: n)
        var phaseAcc: Float = 0
        let duration = Float(n) / sampleRate
        for i in 0..<n {
            let t = Float(i) / sampleRate
            // La frecuencia sube mientras la burbuja colapsa (resonancia de Minnaert).
            let f = f0 * (1 + rise * t / duration)
            phaseAcc += 2 * .pi * f / sampleRate
            out[i] = sin(phaseAcc) * exp(-t / tau) * min(1, t / 0.0006)
        }
        return out
    }

    private static func chiptune(kind: KeyKind, variant: Int, _ rng: inout SeededRandom) -> [Float] {
        let scale: [Float] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
        let base: Float = 523.25
        let notes: [Float]
        switch kind {
        case .space: notes = [base / 2]
        case .enter: notes = [base, base * 1.26, base * 1.498, base * 2]
        case .backspace: notes = [base * 1.498, base]
        case .modifier: notes = [base / 2 * 1.498]
        default:
            let step = scale[(variant * 3 + Int(rng.unit() * 4)) % scale.count]
            notes = [base * pow(2, step / 12)]
        }
        let noteLength = notes.count > 1 ? 0.045 : 0.09
        var out: [Float] = []
        for (i, f) in notes.enumerated() {
            let n = samples(Float(noteLength))
            var tone = [Float](repeating: 0, count: n)
            var phase: Float = 0
            for j in 0..<n {
                let t = Float(j) / sampleRate
                let freq = f * (1 + 0.5 * exp(-t / 0.004))
                phase += freq / sampleRate
                phase -= floor(phase)
                tone[j] = (phase < 0.25 ? 1 : -1) * exp(-t / 0.05) * min(1, t / 0.0005)
            }
            DSP.mix(tone, into: &out, at: samples(Float(noteLength) * 0.8) * i)
        }
        var lp = Biquad.lowPass(9000, sampleRate: sampleRate)
        lp.process(&out)
        return out
    }

    private static func renderMouse(phase: KeyPhase, variant: Int) -> [Float] {
        var rng = SeededRandom(seed: seed("mouse", .mouse, phase, variant))
        var out: [Float] = []
        let isPress = phase == .press
        DSP.mix(click((isPress ? 3300 : 4100) * rng.jitter(0.05), &rng), into: &out, at: 0, gain: 0.8)
        var modes = [Float](repeating: 0, count: samples(0.03))
        for r in [Resonance(isPress ? 2700 : 3300, 0.006, 1), Resonance(isPress ? 5200 : 6100, 0.003, 0.5)] {
            addResonance(r, freqScale: rng.jitter(0.04), decayScale: 1, into: &modes, &rng)
        }
        DSP.normalize(&modes, to: 1)
        DSP.mix(modes, into: &out, at: samples(0.001))
        return finish(out, level: isPress ? 0.5 : 0.35)
    }

    // MARK: - Bloques de construcción

    /// Clic: ráfaga de ruido muy corta filtrada en paso banda.
    private static func click(_ freq: Float, _ rng: inout SeededRandom) -> [Float] {
        let burst = noiseBurst(length: 0.008, tau: 0.0007, &rng)
        var bp1 = Biquad.bandPass(freq, q: 3, sampleRate: sampleRate)
        var bp2 = Biquad.bandPass(freq * 1.7, q: 4, sampleRate: sampleRate)
        var out = burst.map { x in bp1.process(x) + 0.5 * bp2.process(x) }
        DSP.normalize(&out, to: 1)
        return out
    }

    /// Bache táctil: golpe sordo de baja frecuencia.
    private static func tick(_ rng: inout SeededRandom) -> [Float] {
        var out = noiseBurst(length: 0.008, tau: 0.0012, &rng)
        var lp = Biquad.lowPass(2500, sampleRate: sampleRate)
        lp.process(&out)
        DSP.normalize(&out, to: 1)
        return out
    }

    /// Golpe contra el fondo: resonancias amortiguadas + ruido de impacto.
    private static func impact(_ p: SwitchProfile, freqScale: Float, decayScale: Float, _ rng: inout SeededRandom) -> [Float] {
        let longest = p.resonances.map(\.decay).max() ?? 0.02
        let n = samples(min(0.35, longest * decayScale * 7))
        var modes = [Float](repeating: 0, count: n)
        for r in p.resonances {
            addResonance(r, freqScale: freqScale, decayScale: decayScale, into: &modes, &rng)
        }
        DSP.normalize(&modes, to: 1)

        if p.impactNoise > 0 {
            var noise = noiseBurst(length: p.noiseDecay * decayScale * 6, tau: p.noiseDecay * decayScale, &rng)
            var lp = Biquad.lowPass(p.noiseCutoff * freqScale, sampleRate: sampleRate)
            lp.process(&noise)
            DSP.normalize(&noise, to: p.impactNoise)
            DSP.mix(noise, into: &modes, at: 0)
        }
        return modes
    }

    private static func addResonance(_ r: Resonance, freqScale: Float, decayScale: Float, into buffer: inout [Float], _ rng: inout SeededRandom) {
        let f = r.frequency * freqScale * rng.jitter(0.04)
        let d = r.decay * decayScale * rng.jitter(0.1)
        let a = r.amplitude * rng.jitter(0.15)
        let w = 2 * Float.pi * f / sampleRate
        let phase = rng.unit() * 2 * .pi
        for i in buffer.indices {
            let t = Float(i) / sampleRate
            buffer[i] += a * exp(-t / d) * sin(w * Float(i) + phase) * min(1, t / 0.0003)
        }
    }

    /// "Ping" del muelle: tono metálico con un parcial inarmónico.
    private static func ping(_ freq: Float, decay: Float, _ rng: inout SeededRandom) -> [Float] {
        var out = [Float](repeating: 0, count: samples(decay * 5))
        addResonance(Resonance(freq, decay, 1), freqScale: 1, decayScale: 1, into: &out, &rng)
        addResonance(Resonance(freq * 1.47, decay * 0.6, 0.4), freqScale: 1, decayScale: 1, into: &out, &rng)
        DSP.normalize(&out, to: 1)
        return out
    }

    private static func noiseBurst(length: Float, tau: Float, _ rng: inout SeededRandom) -> [Float] {
        let n = max(1, samples(length))
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Float(i) / sampleRate
            out[i] = rng.bipolar() * exp(-t / tau) * min(1, t / 0.0002)
        }
        return out
    }

    private static func samples(_ seconds: Float) -> Int {
        max(0, Int(seconds * sampleRate))
    }

    /// Semilla estable (FNV-1a); `String.hashValue` cambia en cada ejecución.
    private static func seed(_ id: String, _ kind: KeyKind, _ phase: KeyPhase, _ variant: Int) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in "\(id)|\(kind.rawValue)|\(phase.rawValue)|\(variant)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
