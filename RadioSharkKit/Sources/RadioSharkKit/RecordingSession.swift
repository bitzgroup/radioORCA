import AVFoundation

/// Errors thrown by `RecordingSession`.
public enum RecordingSessionError: Error, CustomStringConvertible {
    case alreadyRecording
    case notRecording
    case fileCreationFailed(Error)
    case writeFailed(Error)

    public var description: String {
        switch self {
        case .alreadyRecording:
            return "Already recording"
        case .notRecording:
            return "Not currently recording"
        case .fileCreationFailed(let error):
            return "Failed to create recording file: \(error)"
        case .writeFailed(let error):
            return "Failed to write audio buffer: \(error)"
        }
    }
}

/// Writes captured audio to an AAC (`.m4a`) file
/// (`docs/implementation-plan.md` Phase 2: "録音：AVAudioFileでAAC(.m4a)書き出し").
///
/// Note on the default folder name: this project's default save location
/// is `~/Music/radioORCA/`. Griffin's original app used
/// `~/Music/radioSHARK/` (`docs/app-feature-spec.md` §6), but that name
/// isn't carried over here — "radioSHARK" is Griffin's trademark and this
/// app is named radioORCA (see `CLAUDE.md`).
public final class RecordingSession {
    public static func defaultDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("radioORCA", isDirectory: true)
    }

    public private(set) var isRecording = false
    public private(set) var destinationURL: URL?

    private var file: AVAudioFile?

    public init() {}

    /// Starts writing to a new timestamped `.m4a` file inside `directory`
    /// (created if needed).
    ///
    /// - Parameters:
    ///   - processingFormat: the format buffers will be handed to
    ///     `write(_:)` in (typically the input node's format).
    ///   - stationLabel: e.g. `"FM80.0"`, included in the filename when given.
    @discardableResult
    public func start(
        processingFormat: AVAudioFormat,
        directory: URL = RecordingSession.defaultDirectory(),
        stationLabel: String? = nil,
        date: Date = Date()
    ) throws -> URL {
        guard !isRecording else { throw RecordingSessionError.alreadyRecording }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw RecordingSessionError.fileCreationFailed(error)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
        let name = [stationLabel, timestamp].compactMap { $0 }.joined(separator: "-") + ".m4a"
        let url = directory.appendingPathComponent(name)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: processingFormat.sampleRate,
            AVNumberOfChannelsKey: processingFormat.channelCount,
        ]

        do {
            file = try AVAudioFile(
                forWriting: url,
                settings: outputSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: processingFormat.isInterleaved
            )
        } catch {
            throw RecordingSessionError.fileCreationFailed(error)
        }

        destinationURL = url
        isRecording = true
        return url
    }

    /// Appends a captured buffer to the open file. `AVAudioFile.write`
    /// performs its own (non hard-realtime-safe) I/O — see
    /// `AudioEngineController` for how buffers are handed off from the
    /// input tap.
    public func write(_ buffer: AVAudioPCMBuffer) throws {
        guard isRecording, let file else { throw RecordingSessionError.notRecording }
        do {
            try file.write(from: buffer)
        } catch {
            throw RecordingSessionError.writeFailed(error)
        }
    }

    public func stop() {
        file = nil
        isRecording = false
        destinationURL = nil
    }

    deinit { stop() }
}
