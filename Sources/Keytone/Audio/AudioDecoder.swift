import AVFoundation
import KeytoneCore

enum AudioDecoder {
    static let supportedExtensions: Set<String> = ["wav", "mp3", "m4a", "aif", "aiff", "caf", "flac", "aac", "ogg"]

    /// Decodifica cualquier archivo compatible con Core Audio a mono, 48 kHz.
    static func decodeMono(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return [] }
        try file.read(into: buffer)
        guard let data = buffer.floatChannelData else { return [] }

        let count = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: count)
        for c in 0..<channelCount {
            let channel = data[c]
            for i in 0..<count { mono[i] += channel[i] }
        }
        if channelCount > 1 {
            let scale = 1 / Float(channelCount)
            for i in mono.indices { mono[i] *= scale }
        }
        return DSP.resample(mono, rate: Float(format.sampleRate) / SwitchSynth.sampleRate)
    }
}
