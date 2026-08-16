/// Playback-position state machine for timeshift navigation (Rewind /
/// Fast Forward / Skip Back / Skip Ahead / Live), kept independent of
/// AVFoundation so the transition logic is unit testable without a real
/// audio device — the same rationale as `FrequencyCodec`/`HIDReports`.
///
/// Behavior per `docs/app-feature-spec.md` §2:
/// - Rewind/Fast Forward: repeated presses ratchet up playback speed
///   ("押すたびに速度が上がる可変速").
/// - Skip Back/Ahead: fixed-size jump.
/// - Reaching the live edge while seeking forward returns to `.live`
///   automatically ("Live復帰").
/// - Play/Pause only pauses timeshift playback; recording is unaffected
///   (`RecordingSession` is driven separately by `AudioEngineController`).
///
/// First-pass design note (Phase 2): Rewind/Fast Forward move the *read
/// position* through the buffered timeline rather than playing back
/// reversed or pitch-shifted audio — `AudioEngineController` schedules
/// short snippets from wherever `currentFrame` lands as it moves. This is
/// a deliberately simple "scrub" behavior; revisit if product feedback
/// wants tape-style continuous sped-up audio instead.
public struct TimeshiftPlaybackController {
    public enum Mode: Equatable {
        case live
        case paused
        case seekingBack(rateIndex: Int)
        case seekingForward(rateIndex: Int)
    }

    /// Speed multipliers selected by repeated Rewind/Fast Forward presses.
    public static let rates: [Double] = [1, 2, 4, 8, 16]

    public let sampleRate: Double
    public private(set) var mode: Mode = .live
    public private(set) var currentFrame: Int64 = 0
    public private(set) var oldestAvailableFrame: Int64 = 0
    public private(set) var liveFrame: Int64 = 0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// The speed multiplier implied by the current mode (`1` when live or
    /// paused).
    public var currentRate: Double {
        switch mode {
        case .seekingBack(let index), .seekingForward(let index):
            return Self.rates[index]
        case .live, .paused:
            return 1
        }
    }

    /// Call whenever the timeshift buffer receives new audio, so the live
    /// edge and the oldest-available bound stay current.
    public mutating func advanceLive(toFrame newLiveFrame: Int64, oldestAvailableFrame newOldest: Int64) {
        liveFrame = newLiveFrame
        oldestAvailableFrame = newOldest
        if mode == .live {
            currentFrame = liveFrame
        } else {
            currentFrame = min(currentFrame, liveFrame)
        }
    }

    /// Advances `currentFrame` according to the current mode. Call
    /// regularly (e.g. once per scheduler tick) with the elapsed
    /// wall-clock time since the previous call.
    public mutating func tick(elapsedSeconds: Double) {
        guard elapsedSeconds > 0 else { return }
        switch mode {
        case .live, .paused:
            break
        case .seekingBack(let rateIndex):
            let delta = Int64(elapsedSeconds * sampleRate * Self.rates[rateIndex])
            currentFrame -= delta
            if currentFrame <= oldestAvailableFrame {
                currentFrame = oldestAvailableFrame
                mode = .paused
            }
        case .seekingForward(let rateIndex):
            let delta = Int64(elapsedSeconds * sampleRate * Self.rates[rateIndex])
            currentFrame += delta
            if currentFrame >= liveFrame {
                currentFrame = liveFrame
                mode = .live
            }
        }
    }

    public mutating func pressRewind() {
        switch mode {
        case .seekingBack(let rateIndex):
            mode = .seekingBack(rateIndex: min(rateIndex + 1, Self.rates.count - 1))
        default:
            mode = .seekingBack(rateIndex: 0)
        }
    }

    /// No-op when already at the live edge — there's nothing ahead to
    /// seek to.
    public mutating func pressFastForward() {
        guard currentFrame < liveFrame else { return }
        switch mode {
        case .seekingForward(let rateIndex):
            mode = .seekingForward(rateIndex: min(rateIndex + 1, Self.rates.count - 1))
        default:
            mode = .seekingForward(rateIndex: 0)
        }
    }

    /// Toggles timeshift playback pause. Resumes forward from
    /// `currentFrame` (or straight to `.live` if already caught up).
    public mutating func pressPlayPause() {
        switch mode {
        case .paused:
            mode = currentFrame >= liveFrame ? .live : .seekingForward(rateIndex: 0)
        default:
            mode = .paused
        }
    }

    public mutating func goLive() {
        mode = .live
        currentFrame = liveFrame
    }

    public mutating func skipBack(seconds: Double) {
        currentFrame = max(oldestAvailableFrame, currentFrame - Int64(seconds * sampleRate))
        if mode == .live { mode = .paused }
    }

    public mutating func skipAhead(seconds: Double) {
        currentFrame = min(liveFrame, currentFrame + Int64(seconds * sampleRate))
        if currentFrame >= liveFrame {
            goLive()
        } else if mode == .live {
            mode = .paused
        }
    }
}
