import SwiftUI

/// Playback controls — Volume/Mute/Record/Play-Pause/Live/Rewind/Fast
/// Forward/Skip, plus the Playback Indicator — per
/// `docs/app-feature-spec.md` §1.2/§1.3.
struct PlaybackControlsView: View {
    @ObservedObject var viewModel: RadioViewModel

    var body: some View {
        VStack(spacing: 12) {
            playbackIndicator

            HStack(spacing: 16) {
                Button(action: viewModel.skipBack) {
                    Image(systemName: "backward.end.fill")
                }
                .keyboardShortcut(.home, modifiers: [])
                .help(String(localized: "Skip Back"))

                Button(action: viewModel.pressRewind) {
                    Image(systemName: "backward.fill")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help(String(localized: "Rewind"))

                Button(action: viewModel.togglePlayPause) {
                    Image(systemName: playPauseSymbol)
                }
                .keyboardShortcut(.space, modifiers: [])
                .foregroundStyle(viewModel.isLive ? Color.primary : Color.green)
                .help(String(localized: "Play/Pause"))

                Button(action: viewModel.pressFastForward) {
                    Image(systemName: "forward.fill")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help(String(localized: "Fast Forward"))

                Button(action: viewModel.skipAhead) {
                    Image(systemName: "forward.end.fill")
                }
                .keyboardShortcut(.end, modifiers: [])
                .help(String(localized: "Skip Ahead"))

                Button(action: viewModel.goLive) {
                    Text("LIVE")
                        .font(.caption.bold())
                }
                .keyboardShortcut("l", modifiers: [])
                .disabled(viewModel.isLive)
                .help(String(localized: "Return to Live"))
            }
            .buttonStyle(.bordered)

            HStack(spacing: 12) {
                Button(action: viewModel.toggleMute) {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .help(String(localized: "Mute"))

                Slider(
                    value: $viewModel.volume,
                    in: 0...1
                )
                .frame(maxWidth: 160)

                Button(action: viewModel.toggleRecord) {
                    Image(systemName: viewModel.isRecording ? "record.circle.fill" : "record.circle")
                }
                .keyboardShortcut("s", modifiers: [.command])
                .foregroundStyle(viewModel.isRecording ? .red : .primary)
                .help(String(localized: "Start Recording"))
            }
        }
    }

    private var playPauseSymbol: String {
        switch viewModel.timeshiftStatus?.mode {
        case .paused: return "play.fill"
        case .live, .none: return "pause.fill"
        case .seekingBack, .seekingForward: return "pause.fill"
        }
    }

    @ViewBuilder
    private var playbackIndicator: some View {
        if viewModel.isLive {
            Text("LIVE")
                .font(.caption.bold())
                .foregroundStyle(.green)
        } else {
            Text(timecodeText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var timecodeText: String {
        let seconds = Int(viewModel.timeshiftStatus?.secondsBehindLive ?? 0)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "-%d:%02d", minutes, remainder)
    }
}

#Preview {
    PlaybackControlsView(viewModel: RadioViewModel())
        .padding()
}
