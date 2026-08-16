import AVFoundation
import AudioToolbox

/// Errors thrown by `AudioEngineController`.
public enum AudioEngineControllerError: Error, CustomStringConvertible {
    case deviceNotFound
    case engineStartFailed(Error)
    case setDeviceFailed(OSStatus)

    public var description: String {
        switch self {
        case .deviceNotFound:
            return "radioSHARK audio input not found (check that it's connected)"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error)"
        case .setDeviceFailed(let status):
            return "Failed to select radioSHARK as the input device (status \(status))"
        }
    }
}

/// Whether `AudioEngineController` currently has a running engine routed
/// to the radioSHARK audio input. Phase 3 wires this into the app's Fin
/// connection indicator (`docs/implementation-plan.md` Phase 2:
/// "デバイス未接続時／切断時のハンドリング").
public enum AudioEngineConnectionState: Equatable, Sendable {
    case disconnected
    case connected
}

/// Coordinates live monitoring, recording, and timeshift playback for the
/// radioSHARK 2's USB audio input (`docs/implementation-plan.md` Phase 2).
///
/// ## Why two `AVAudioEngine`s
///
/// The original design (per the plan's "inputNode → outputNode 直結")
/// assumed a single engine could bind its `inputNode` to radioSHARK while
/// `outputNode` kept using the Mac's regular speakers. **Real-device
/// testing showed this doesn't hold on macOS**: `AVAudioEngine.inputNode`
/// and `.outputNode` share one HAL I/O unit, so pointing the input at a
/// specific `AudioDeviceID` repoints the *output* to that same device too.
/// radioSHARK reports 0 output channels (confirmed via
/// `system_profiler SPAudioDataType`: "Input Channels: 2", no "Output
/// Channels" line), so that shared-device engine fails to start
/// (`kAudioUnitErr_FormatNotSupported` / "IsFormatSampleRateAndChannelCountValid").
///
/// The fix: two engines.
/// - `captureEngine` — its `inputNode` is routed to radioSHARK via
///   `kAudioOutputUnitProperty_CurrentDevice`; only used for capture (a
///   tap on `inputNode`), never connected to its own output.
/// - `playbackEngine` — untouched, uses the system's regular default
///   output device; a single `player` node plays both live audio and
///   timeshift snippets through it.
///
/// Live monitoring is therefore "forward each captured buffer to
/// `player` immediately" (one buffer of added latency, ~85ms at the
/// tap's 4096-frame size) rather than a same-engine graph connection —
/// still near-real-time, just not literally zero-latency passthrough.
///
/// ## Timeshift playback
///
/// A tap on `captureEngine.inputNode` copies every captured buffer into
/// a `TimeshiftBuffer` (rolling circular buffer) and, while recording,
/// into a `RecordingSession` AAC file. When the user seeks away from
/// Live, a periodic scheduler reads short (~200ms) snippets from the
/// `TimeshiftBuffer` at `transport.currentFrame` and schedules them on
/// `player` instead of forwarding live buffers — see
/// `TimeshiftPlaybackController`'s doc comment for why this is a "scrub
/// snippets" design rather than continuous sped-up/reversed audio.
///
/// ## Thread-safety
///
/// The capture tap fires on a dedicated AVAudioEngine callback thread,
/// while transport controls (`pressRewind()` etc.) are expected to be
/// called from the app's main thread. `stateLock` guards the state both
/// sides touch (`timeshiftBuffer`, `transport`, `previousMode`).
public final class AudioEngineController: @unchecked Sendable {
    private let captureEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private let stateLock = NSLock()
    private var timeshiftBuffer: TimeshiftBuffer?
    private var transport: TimeshiftPlaybackController?
    private var previousMode: TimeshiftPlaybackController.Mode?

    public let recordingSession = RecordingSession()

    private var schedulerTimer: Timer?
    private var lastTickDate: Date?
    private var captureFormat: AVAudioFormat?

    private let connectionLock = NSLock()
    private var _connectionState: AudioEngineConnectionState = .disconnected
    public private(set) var connectionState: AudioEngineConnectionState {
        get { connectionLock.withUnsafeLock { _connectionState } }
        set { connectionLock.withUnsafeLock { _connectionState = newValue } }
    }

    /// Called on the main thread whenever `connectionState` changes.
    public var onConnectionStateChange: ((AudioEngineConnectionState) -> Void)?

    public init() {}

    /// Finds the radioSHARK audio device, routes `captureEngine`'s input
    /// node to it, starts `playbackEngine` on the system's regular
    /// output, and begins live monitoring. Call `stop()` on device
    /// disconnect.
    public func start(timeshiftCapacityMinutes: Double = 10) throws {
        let deviceID = try AudioDeviceMatch.findDeviceID()
        try selectInputDevice(deviceID, on: captureEngine)

        let format = captureEngine.inputNode.inputFormat(forBus: 0)
        captureFormat = format

        playbackEngine.attach(player)
        playbackEngine.connect(player, to: playbackEngine.mainMixerNode, format: format)

        withStateLock {
            timeshiftBuffer = TimeshiftBuffer(
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount),
                capacityMinutes: timeshiftCapacityMinutes
            )
            transport = TimeshiftPlaybackController(sampleRate: format.sampleRate)
            previousMode = .live
        }

        captureEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handleCapturedBuffer(buffer)
        }

        do {
            try captureEngine.start()
        } catch {
            captureEngine.inputNode.removeTap(onBus: 0)
            throw AudioEngineControllerError.engineStartFailed(error)
        }

        do {
            try playbackEngine.start()
        } catch {
            captureEngine.inputNode.removeTap(onBus: 0)
            captureEngine.stop()
            throw AudioEngineControllerError.engineStartFailed(error)
        }

        player.play()
        startScheduler()

        connectionState = .connected
        onConnectionStateChange?(.connected)
    }

    /// Stops both engines and releases all audio state. Safe to call
    /// even if `start()` was never called or already failed.
    public func stop() {
        stopScheduler()
        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()
        player.stop()
        playbackEngine.stop()
        recordingSession.stop()
        withStateLock {
            timeshiftBuffer = nil
            transport = nil
            previousMode = nil
        }
        connectionState = .disconnected
        onConnectionStateChange?(.disconnected)
    }

    /// Convenience wiring: starts/stops the audio engine automatically as
    /// `discovery` reports the radioSHARK connecting/disconnecting.
    /// Errors from `start()` on (re)connect are swallowed here — observe
    /// `connectionState`/`onConnectionStateChange` (it simply won't
    /// transition to `.connected`) if the caller needs to surface them.
    public func observe(_ discovery: DeviceDiscovery) {
        discovery.onConnect = { [weak self] in try? self?.start() }
        discovery.onDisconnect = { [weak self] in self?.stop() }
    }

    // MARK: - Recording

    /// Starts writing to a new AAC file (`RecordingSession.defaultDirectory()`).
    /// Independent of timeshift/live playback state — per
    /// `docs/app-feature-spec.md` §2, pausing playback never pauses
    /// recording.
    @discardableResult
    public func startRecording(stationLabel: String? = nil) throws -> URL {
        guard let captureFormat else { throw AudioEngineControllerError.deviceNotFound }
        return try recordingSession.start(processingFormat: captureFormat, stationLabel: stationLabel)
    }

    public func stopRecording() {
        recordingSession.stop()
    }

    // MARK: - Timeshift transport

    public func pressRewind() { withStateLock { transport?.pressRewind() } }
    public func pressFastForward() { withStateLock { transport?.pressFastForward() } }
    public func pressPlayPause() { withStateLock { transport?.pressPlayPause() } }
    public func goLive() { withStateLock { transport?.goLive() } }
    public func skipBack(seconds: Double = 30) { withStateLock { transport?.skipBack(seconds: seconds) } }
    public func skipAhead(seconds: Double = 30) { withStateLock { transport?.skipAhead(seconds: seconds) } }

    public var isLive: Bool {
        withStateLock { transport?.mode ?? .live } == .live
    }

    // MARK: - Private: locking helpers

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    // MARK: - Private: device routing

    private func selectInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw AudioEngineControllerError.deviceNotFound
        }
        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw AudioEngineControllerError.setDeviceFailed(status) }
    }

    // MARK: - Private: capture (runs on captureEngine's tap callback thread)

    private func handleCapturedBuffer(_ buffer: AVAudioPCMBuffer) {
        if recordingSession.isRecording {
            try? recordingSession.write(buffer)
        }
        guard let interleaved = buffer.interleavedFloatSamples() else { return }

        let isLiveMode = withStateLock { () -> Bool in
            timeshiftBuffer?.write(interleaved: interleaved)
            if let timeshiftBuffer {
                transport?.advanceLive(
                    toFrame: timeshiftBuffer.liveFrame,
                    oldestAvailableFrame: timeshiftBuffer.oldestAvailableFrame
                )
            }
            return transport?.mode == .live
        }

        // Live monitoring: forward the buffer straight to the playback
        // engine's player instead of waiting for the scrub scheduler —
        // this is what keeps Live low-latency.
        if isLiveMode {
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }

    // MARK: - Private: timeshift scheduler (main-thread timer)

    private func startScheduler() {
        lastTickDate = Date()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.schedulerTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        schedulerTimer = timer
    }

    private func stopScheduler() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        lastTickDate = nil
    }

    private func schedulerTick() {
        let now = Date()
        let elapsed = lastTickDate.map { now.timeIntervalSince($0) } ?? 0
        lastTickDate = now

        struct Snapshot {
            let mode: TimeshiftPlaybackController.Mode
            let frame: Int64
            let justTransitioned: Bool
        }

        let snapshot: Snapshot? = withStateLock {
            guard var transport else { return nil }
            transport.tick(elapsedSeconds: elapsed)
            let justTransitioned = transport.mode != previousMode
            previousMode = transport.mode
            self.transport = transport
            return Snapshot(mode: transport.mode, frame: transport.currentFrame, justTransitioned: justTransitioned)
        }
        guard let snapshot else { return }

        if snapshot.justTransitioned {
            // Flush whatever's queued so a mode change (entering/leaving
            // Live) is audible immediately instead of finishing out
            // stale scheduled audio.
            player.stop()
            player.play()
        }

        // Live playback is handled directly in handleCapturedBuffer(); the
        // scheduler only drives scrub snippets while seeking/paused.
        guard snapshot.mode != .live, let format = captureFormat else { return }

        let snippetFrames = max(1, Int(format.sampleRate * 0.2))
        let samples = withStateLock {
            timeshiftBuffer?.read(fromFrame: snapshot.frame, frameCount: snippetFrames)
        }
        guard let samples, let snippet = AVAudioPCMBuffer.makeFloatBuffer(interleaved: samples, format: format) else {
            return
        }
        player.scheduleBuffer(snippet, at: nil, options: .interrupts)
    }
}

extension NSLock {
    fileprivate func withUnsafeLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
