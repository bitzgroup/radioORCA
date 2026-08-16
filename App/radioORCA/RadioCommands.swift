import SwiftUI

/// Menu-bar commands mirroring `docs/app-feature-spec.md` §7's shortcut
/// table. `⌘M` (Minimize Window) isn't listed here — it's already the
/// system default for any `WindowGroup` scene.
///
/// `⌘,` is mapped to "Open Presets" per the original manual's table,
/// rather than the usual macOS convention of opening app Preferences —
/// Phase 5 adds a real Preferences window, at which point this will need
/// to be revisited (`docs/implementation-plan.md` Phase 5).
struct RadioCommands: Commands {
    @ObservedObject var viewModel: RadioViewModel
    @Binding var isFavoritesPresented: Bool

    var body: some Commands {
        CommandMenu(String(localized: "Tuning")) {
            Button(String(localized: "Tune Up")) { viewModel.tuneUp() }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button(String(localized: "Tune Down")) { viewModel.tuneDown() }
                .keyboardShortcut(.downArrow, modifiers: [])
            Divider()
            // No signal-strength feedback is available from the hardware
            // protocol, so Seek steps like Tune Up/Down for now — see
            // RadioViewModel.seekUp()/seekDown().
            Button(String(localized: "Seek Up")) { viewModel.seekUp() }
                .keyboardShortcut(.tab, modifiers: [])
            Button(String(localized: "Seek Down")) { viewModel.seekDown() }
                .keyboardShortcut(.tab, modifiers: [.shift])
        }

        CommandMenu(String(localized: "Playback")) {
            Button(String(localized: "Play/Pause")) { viewModel.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
            Button(String(localized: "Live")) { viewModel.goLive() }
                .keyboardShortcut("l", modifiers: [])
            Divider()
            Button(String(localized: "Rewind")) { viewModel.pressRewind() }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button(String(localized: "Fast Forward")) { viewModel.pressFastForward() }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Divider()
            Button(String(localized: "Skip Back")) { viewModel.skipBack() }
                .keyboardShortcut(.home, modifiers: [])
            Button(String(localized: "Skip Ahead")) { viewModel.skipAhead() }
                .keyboardShortcut(.end, modifiers: [])
            Divider()
            Button(String(localized: "Volume Up")) { viewModel.volumeUp() }
                .keyboardShortcut("=", modifiers: [.command])
            Button(String(localized: "Volume Down")) { viewModel.volumeDown() }
                .keyboardShortcut("-", modifiers: [.command])
            Button(String(localized: "Mute")) { viewModel.toggleMute() }
            Divider()
            Button(String(localized: "Start Recording")) { viewModel.toggleRecord() }
                .keyboardShortcut("s", modifiers: [.command])
        }

        CommandMenu(String(localized: "Station")) {
            Button(String(localized: "Station Info…")) { isFavoritesPresented = true }
                .keyboardShortcut("i", modifiers: [.command])
            Button(String(localized: "Set Favorite")) { viewModel.addFavorite(description: viewModel.band.stationLabel(for: viewModel.frequency)) }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(viewModel.currentFavorite != nil)
            Button(String(localized: "Open Presets")) { isFavoritesPresented = true }
                .keyboardShortcut(",", modifiers: [.command])
            Divider()
            ForEach(1...9, id: \.self) { key in
                Button(presetLabel(key)) { viewModel.selectPreset(key) }
                    .keyboardShortcut(KeyEquivalent(Character("\(key)")), modifiers: [.command])
            }
        }

        CommandGroup(replacing: .help) {
            Button(String(localized: "radioORCA Help")) { openHelp() }
                .keyboardShortcut("h", modifiers: [.command])
        }
    }

    private func presetLabel(_ key: Int) -> String {
        if let favorite = viewModel.favoritesStore.favorite(forPresetKey: key) {
            return "\(key). \(favorite.description.isEmpty ? favorite.stationLabel : favorite.description)"
        }
        return String(format: String(localized: "Preset %d"), key)
    }

    private func openHelp() {
        guard let url = URL(string: "https://github.com/bitzgroup/radioORCA") else { return }
        NSWorkspace.shared.open(url)
    }
}
