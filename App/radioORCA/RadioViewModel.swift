import Combine
import Foundation
import RadioSharkKit

/// Fin (USB connection indicator) state, per
/// `docs/app-feature-spec.md` §1.3: "グレー：未接続 / 青：接続中 /
/// 赤：接続中＋録音中". The fourth state from the manual ("USBアイコン
/// 点滅：デバイス未検出") isn't distinguishable from `.disconnected` with
/// what `DeviceDiscovery` reports today, so it's folded into `.disconnected`.
enum FinState {
    case disconnected
    case connected
    case recording
}

/// Owns the app's live state and wires `RadioSharkKit`'s device/audio
/// layers to the SwiftUI views (`docs/implementation-plan.md` Phase 3).
///
/// `ObservableObject` (not `@Observable`) because the project's deployment
/// target is macOS 13 (see `project.yml`); the `Observation` framework
/// backing `@Observable` requires macOS 14+.
@MainActor
final class RadioViewModel: ObservableObject {
    let favoritesStore: FavoritesStore

    private let hid = HIDController()
    private let audio = AudioEngineController()
    private let discovery = DeviceDiscovery()

    @Published private(set) var isHardwareConnected = false
    @Published private(set) var isRecording = false
    @Published private(set) var timeshiftStatus: AudioEngineController.TimeshiftStatus?
    @Published private(set) var errorMessage: String?

    @Published var region: TuningRegion = .systemDefault {
        didSet {
            // Skipped while `restoreTuningState()` is assigning `region`
            // as part of loading a full snapshot — running this logic
            // there would re-derive/overwrite `band`/`savedFrequencies`
            // from incomplete, not-yet-restored state and clobber the
            // persisted data with it.
            guard !isRestoring else { return }
            // Re-clamp every band's remembered frequency into the new
            // region's range, not just the currently active one.
            for candidate in RadioBand.allCases {
                if let saved = savedFrequencies[candidate] {
                    savedFrequencies[candidate] = candidate.clamp(saved, for: region)
                }
            }
            frequency = band.clamp(frequency, for: region)
            savedFrequencies[band] = frequency
            try? tune()
            persistTuningState()
        }
    }
    @Published var band: RadioBand = .fm
    @Published var frequency: Double = RadioBand.fm.defaultFrequency(for: .systemDefault)

    /// Remembers the last frequency tuned on each band, so switching
    /// AM↔FM doesn't lose where you were (per user feedback: switching
    /// bands should preserve the entered frequency instead of resetting
    /// to the region's default). Persisted to `UserDefaults` (see
    /// `persistTuningState()`/`restoreTuningState()`) so it also survives
    /// relaunching the app — per user feedback, forgetting the tuned
    /// frequency on every launch made the app hard to use.
    private var savedFrequencies: [RadioBand: Double] = [:]

    /// Guards `region`'s `didSet` while `restoreTuningState()` is
    /// assigning a full snapshot — see that property's doc comment.
    private var isRestoring = false

    private static let tuningStateDefaultsKey = "tuningState"

    private struct PersistedTuningState: Codable {
        var band: RadioBand
        var region: TuningRegion
        var savedFrequencies: [RadioBand: Double]
    }

    @Published var volume: Double = 0.8 {
        didSet { applyVolume() }
    }
    @Published var isMuted = false {
        didSet { applyVolume() }
    }

    private var statusTimer: Timer?

    var finState: FinState {
        guard isHardwareConnected else { return .disconnected }
        return isRecording ? .recording : .connected
    }

    var isLive: Bool {
        timeshiftStatus?.mode == .live
    }

    /// The favorite matching the current band/frequency, if any — used to
    /// show its Description in the Station Description field instead of a
    /// bare frequency (`docs/app-feature-spec.md` §1.3).
    var currentFavorite: Favorite? {
        favoritesStore.favorites.first { $0.band == band && $0.frequency == frequency }
    }

    init(favoritesStore: FavoritesStore = FavoritesStore()) {
        self.favoritesStore = favoritesStore
        restoreTuningState()
    }

    // MARK: - Tuning state persistence

    private func restoreTuningState() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.tuningStateDefaultsKey),
            let state = try? JSONDecoder().decode(PersistedTuningState.self, from: data)
        else { return }
        isRestoring = true
        region = state.region
        band = state.band
        savedFrequencies = state.savedFrequencies
        frequency = savedFrequencies[band] ?? band.defaultFrequency(for: region)
        isRestoring = false
    }

    private func persistTuningState() {
        let state = PersistedTuningState(band: band, region: region, savedFrequencies: savedFrequencies)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.tuningStateDefaultsKey)
    }

    // MARK: - Lifecycle

    /// Starts device discovery and the periodic UI status refresh. Call
    /// once from the app's root view `.task`/`.onAppear`.
    func start() {
        discovery.onConnect = { [weak self] in
            Task { @MainActor in self?.handleConnect() }
        }
        discovery.onDisconnect = { [weak self] in
            Task { @MainActor in self?.handleDisconnect() }
        }
        discovery.start()
        startStatusTimer()
    }

    func stop() {
        statusTimer?.invalidate()
        statusTimer = nil
        discovery.stop()
        handleDisconnect()
    }

    private func handleConnect() {
        do {
            try hid.connect()
            isHardwareConnected = true
            errorMessage = nil
            // Fin実機連動：接続時に青色LEDを点灯させる
            // (docs/hardware-protocol.md §4.1/4.2, app-feature-spec.md §1.3)。
            try? hid.setBlueLight(level: 127)
            try? tune()
        } catch {
            isHardwareConnected = false
            errorMessage = "\(error)"
        }

        do {
            try audio.start()
            applyVolume()
        } catch {
            // オーディオが取れなくてもHID制御（LED・選局）は独立して使える
            // ため、致命的エラーにはしない。
            errorMessage = "\(error)"
        }
    }

    private func handleDisconnect() {
        hid.disconnect()
        audio.stop()
        isHardwareConnected = false
        isRecording = false
        timeshiftStatus = nil
    }

    // MARK: - Tuning

    func setBand(_ newBand: RadioBand) {
        guard newBand != band else { return }
        savedFrequencies[band] = frequency
        band = newBand
        let restored = savedFrequencies[newBand] ?? newBand.defaultFrequency(for: region)
        frequency = newBand.clamp(restored, for: region)
        savedFrequencies[newBand] = frequency
        try? tune()
        persistTuningState()
    }

    func setFrequency(_ newFrequency: Double) {
        frequency = band.clamp(newFrequency, for: region)
        savedFrequencies[band] = frequency
        try? tune()
        persistTuningState()
    }

    func tuneUp() { setFrequency(frequency + band.tuneStep(for: region)) }
    func tuneDown() { setFrequency(frequency - band.tuneStep(for: region)) }

    /// The hardware protocol has no signal-strength input report
    /// (`docs/hardware-protocol.md` has no such HID input field), so a
    /// real auto-scan "seek" isn't implementable yet. For the MVP this
    /// steps like Tune Up/Down — see `docs/app-feature-spec.md` §1.1
    /// "Tabキー".
    func seekUp() { tuneUp() }
    func seekDown() { tuneDown() }

    private func tune() throws {
        guard isHardwareConnected else { return }
        switch band {
        case .fm:
            try hid.tuneFM(megahertz: frequency)
        case .am:
            try hid.tuneAM(kilohertz: Int(frequency.rounded()))
        }
    }

    // MARK: - Volume / mute

    func volumeUp() { volume = min(1, volume + 0.05) }
    func volumeDown() { volume = max(0, volume - 0.05) }
    func toggleMute() { isMuted.toggle() }

    private func applyVolume() {
        audio.volume = Float(isMuted ? 0 : volume)
    }

    // MARK: - Recording

    func toggleRecord() {
        if isRecording {
            audio.stopRecording()
            isRecording = false
            try? hid.setRedLight(level: 0)
        } else {
            do {
                _ = try audio.startRecording(stationLabel: band.stationLabel(for: frequency))
                isRecording = true
                // Fin赤色＝接続中＋録音中 (app-feature-spec.md §1.3)。
                try? hid.setRedLight(level: 127)
            } catch {
                errorMessage = "\(error)"
            }
        }
    }

    // MARK: - Timeshift transport

    func pressRewind() { audio.pressRewind() }
    func pressFastForward() { audio.pressFastForward() }
    func togglePlayPause() { audio.pressPlayPause() }
    func goLive() { audio.goLive() }
    func skipBack() { audio.skipBack(seconds: 30) }
    func skipAhead() { audio.skipAhead(seconds: 30) }

    // MARK: - Favorites

    func addFavorite(description: String) {
        favoritesStore.add(Favorite(band: band, frequency: frequency, description: description))
    }

    func selectFavorite(_ favorite: Favorite) {
        band = favorite.band
        setFrequency(favorite.frequency)
    }

    func selectPreset(_ key: Int) {
        guard let favorite = favoritesStore.favorite(forPresetKey: key) else { return }
        selectFavorite(favorite)
    }

    // MARK: - Private: status polling

    private func startStatusTimer() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    private func refreshStatus() {
        timeshiftStatus = audio.timeshiftStatus
    }
}
