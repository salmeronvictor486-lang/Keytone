import Foundation

/// Generador pseudoaleatorio determinista (SplitMix64): mismas semillas, mismos sonidos.
public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Valor uniforme entre 0 y 1.
    public mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    /// Valor uniforme entre -1 y 1.
    public mutating func bipolar() -> Float {
        unit() * 2 - 1
    }

    /// Multiplicador alrededor de 1 con la variación indicada (0.05 = ±5 %).
    public mutating func jitter(_ amount: Float) -> Float {
        1 + bipolar() * amount
    }
}

/// Filtro biquad (fórmulas del "Audio EQ Cookbook" de RBJ).
public struct Biquad {
    private var b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
    private var z1: Float = 0, z2: Float = 0

    private init(b0: Float, b1: Float, b2: Float, a0: Float, a1: Float, a2: Float) {
        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }

    private static func coefficients(_ freq: Float, _ q: Float, _ sampleRate: Float) -> (cos: Float, alpha: Float) {
        let nyquistSafe = min(freq, sampleRate * 0.45)
        let w0 = 2 * Float.pi * nyquistSafe / sampleRate
        return (cos(w0), sin(w0) / (2 * q))
    }

    public static func lowPass(_ freq: Float, q: Float = 0.707, sampleRate: Float) -> Biquad {
        let (c, alpha) = coefficients(freq, q, sampleRate)
        return Biquad(b0: (1 - c) / 2, b1: 1 - c, b2: (1 - c) / 2, a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    public static func highPass(_ freq: Float, q: Float = 0.707, sampleRate: Float) -> Biquad {
        let (c, alpha) = coefficients(freq, q, sampleRate)
        return Biquad(b0: (1 + c) / 2, b1: -(1 + c), b2: (1 + c) / 2, a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    public static func bandPass(_ freq: Float, q: Float, sampleRate: Float) -> Biquad {
        let (c, alpha) = coefficients(freq, q, sampleRate)
        return Biquad(b0: alpha, b1: 0, b2: -alpha, a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    public mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    public mutating func process(_ buffer: inout [Float]) {
        for i in buffer.indices {
            buffer[i] = process(buffer[i])
        }
    }
}

public enum DSP {
    /// Mezcla `source` sobre `target` empezando en `offset`, ampliando `target` si hace falta.
    public static func mix(_ source: [Float], into target: inout [Float], at offset: Int, gain: Float = 1) {
        guard offset >= 0, !source.isEmpty else { return }
        if target.count < offset + source.count {
            target.append(contentsOf: [Float](repeating: 0, count: offset + source.count - target.count))
        }
        for i in source.indices {
            target[offset + i] += source[i] * gain
        }
    }

    public static func peak(_ buffer: [Float]) -> Float {
        buffer.reduce(0) { max($0, abs($1)) }
    }

    /// Normaliza al pico indicado.
    public static func normalize(_ buffer: inout [Float], to target: Float) {
        let p = peak(buffer)
        guard p > 0.000_01 else { return }
        let g = target / p
        for i in buffer.indices { buffer[i] *= g }
    }

    /// Recorta el silencio final y aplica un pequeño fundido para evitar chasquidos.
    public static func trimTail(_ buffer: inout [Float], threshold: Float = 0.0008, sampleRate: Float) {
        guard let last = buffer.lastIndex(where: { abs($0) > threshold }) else {
            buffer.removeAll()
            return
        }
        let fade = Int(sampleRate * 0.003)
        let end = min(buffer.count, last + fade)
        buffer.removeSubrange(end..<buffer.count)
        let start = max(0, end - fade)
        for i in start..<end {
            buffer[i] *= Float(end - i) / Float(max(1, end - start))
        }
    }

    /// Remuestreo lineal: rate > 1 sube el tono y acorta el sonido.
    public static func resample(_ buffer: [Float], rate: Float) -> [Float] {
        guard rate > 0, abs(rate - 1) > 0.0001, buffer.count > 1 else { return buffer }
        let count = max(1, Int(Float(buffer.count - 1) / rate))
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let pos = Float(i) * rate
            let index = Int(pos)
            let frac = pos - Float(index)
            let a = buffer[index]
            let b = index + 1 < buffer.count ? buffer[index + 1] : a
            out[i] = a + (b - a) * frac
        }
        return out
    }
}
