import AudioToolbox
import AVFoundation
import KeytoneCore

/// Reproductor de baja latencia: un grupo de voces que se reparten las pulsaciones.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let limiter: AVAudioUnitEffect
    private let format: AVAudioFormat
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private var configObserver: NSObjectProtocol?

    private(set) var isRunning = false

    init(voiceCount: Int = 24) {
        format = AVAudioFormat(standardFormatWithSampleRate: Double(SwitchSynth.sampleRate), channels: 2)!
        // Limitador de picos: escribir muy rápido no satura aunque se solapen muchas teclas.
        limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        ))

        engine.attach(limiter)
        let mixer = engine.mainMixerNode
        engine.connect(mixer, to: limiter, format: nil)
        engine.connect(limiter, to: engine.outputNode, format: nil)

        for _ in 0..<voiceCount {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: mixer, format: format)
            voices.append(voice)
        }
        engine.prepare()

        // Al cambiar de salida (AirPods, altavoces…) el motor se para: lo rearrancamos.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.isRunning = false
            self.start()
        }
    }

    deinit {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        do {
            try engine.start()
            voices.forEach { $0.play() }
            isRunning = true
        } catch {
            NSLog("Keytone: no se pudo iniciar el audio: \(error)")
            isRunning = false
        }
        return isRunning
    }

    func stop() {
        guard isRunning else { return }
        voices.forEach { $0.stop() }
        engine.stop()
        isRunning = false
    }

    /// Reproduce una muestra mono.
    /// - Parameters:
    ///   - pan: -1 (izquierda) … 1 (derecha).
    ///   - rate: velocidad/tono; 1 = original.
    func play(_ sample: [Float], volume: Float, pan: Float, rate: Float) {
        guard !sample.isEmpty, start() else { return }
        let source = DSP.resample(sample, rate: rate)
        let frames = AVAudioFrameCount(source.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData else { return }
        buffer.frameLength = frames

        let p = max(-1, min(1, pan))
        let left = min(1, 1 - p) * volume
        let right = min(1, 1 + p) * volume
        let l = channels[0], r = channels[1]
        for i in 0..<source.count {
            l[i] = source[i] * left
            r[i] = source[i] * right
        }

        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        if !voice.isPlaying { voice.play() }
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
}
