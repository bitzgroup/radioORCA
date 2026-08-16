import AVFoundation

/// Conversions between `AVAudioPCMBuffer` (AVFoundation's realtime audio
/// container) and plain interleaved `[Float]` (what `TimeshiftBuffer`
/// stores). Kept as a small isolated extension so the pure buffer/state
/// logic elsewhere never has to import AVFoundation.
extension AVAudioPCMBuffer {
    /// This buffer's audio as interleaved Float32 samples
    /// (`frameLength × channelCount`), regardless of whether the
    /// buffer's own storage is interleaved or planar.
    func interleavedFloatSamples() -> [Float]? {
        guard let channelData = floatChannelData else { return nil }
        let frameCount = Int(frameLength)
        let channelCount = Int(format.channelCount)
        var result = [Float](repeating: 0, count: frameCount * channelCount)
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                result[frame * channelCount + channel] = channelData[channel][frame]
            }
        }
        return result
    }

    /// Builds a new buffer from interleaved Float32 samples, for
    /// scheduling on a player node. Returns `nil` for empty input.
    static func makeFloatBuffer(interleaved samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let channelCount = Int(format.channelCount)
        guard channelCount > 0 else { return nil }
        let frameCount = samples.count / channelCount
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else { return nil }
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                channelData[channel][frame] = samples[frame * channelCount + channel]
            }
        }
        return buffer
    }
}
