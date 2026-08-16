/// Circular audio buffer that stores the most recent N minutes of
/// interleaved PCM audio for timeshift (Rewind / Fast Forward / Skip)
/// playback (`docs/implementation-plan.md` Phase 2).
///
/// Pure Swift, no AVFoundation dependency — frame bookkeeping is unit
/// tested directly with plain `[Float]` arrays. `AudioEngineController`
/// is responsible for converting to/from `AVAudioPCMBuffer`.
public struct TimeshiftBuffer {
    public let sampleRate: Double
    public let channelCount: Int
    private var ring: RingBuffer<Float>

    /// - Parameters:
    ///   - sampleRate: e.g. `48_000` (radioSHARK 2's fixed input rate;
    ///     see `docs/hardware-protocol.md` §11).
    ///   - channelCount: e.g. `2` (radioSHARK 2 is stereo).
    ///   - capacityMinutes: rolling buffer length. Default 10 minutes per
    ///     `docs/implementation-plan.md` Phase 2 ("既定10分、設定可能").
    public init(sampleRate: Double, channelCount: Int, capacityMinutes: Double = 10) {
        precondition(channelCount > 0, "channelCount must be positive")
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        let capacityFrames = max(1, Int(sampleRate * capacityMinutes * 60))
        self.ring = RingBuffer(capacity: capacityFrames * channelCount, initialElement: 0)
    }

    /// Buffer length expressed in frames (not samples — divides out
    /// `channelCount`).
    public var capacityFrames: Int64 { Int64(ring.capacity / channelCount) }

    /// Absolute frame index one past the most recently written frame —
    /// the position "Live" playback tracks.
    public var liveFrame: Int64 { ring.totalWritten / Int64(channelCount) }

    /// Oldest frame index still available for playback.
    public var oldestAvailableFrame: Int64 { ring.oldestAvailableIndex / Int64(channelCount) }

    /// Appends interleaved samples. `samples.count` must be a multiple of
    /// `channelCount`.
    public mutating func write(interleaved samples: [Float]) {
        precondition(samples.count % channelCount == 0, "sample count must be a multiple of channelCount")
        ring.write(samples)
    }

    /// Reads `frameCount` interleaved frames starting at absolute frame
    /// `startFrame`. Returns `nil` if the range isn't (or is no longer)
    /// available.
    public func read(fromFrame startFrame: Int64, frameCount: Int) -> [Float]? {
        ring.read(from: startFrame * Int64(channelCount), count: frameCount * channelCount)
    }
}
