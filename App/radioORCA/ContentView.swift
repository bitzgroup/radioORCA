import RadioSharkKit
import SwiftUI

/// Main window — tuning, playback controls, and the Fin connection status
/// (`docs/app-feature-spec.md` §1, `docs/implementation-plan.md` Phase 3).
struct ContentView: View {
    @ObservedObject var viewModel: RadioViewModel
    /// Owned by `RadioORCAApp` so both this view and `RadioCommands` (the
    /// menu-bar ⌘I/⌘, shortcuts) can present the same sheet.
    @Binding var isFavoritesPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            header
            TuningView(viewModel: viewModel)
            Divider()
            PlaybackControlsView(viewModel: viewModel)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 420)
        .task { viewModel.start() }
        .sheet(isPresented: $isFavoritesPresented) {
            FavoritesView(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack {
            FinIndicatorView(state: viewModel.finState)
            Text(stationTitle)
                .font(.title3.bold())
                .lineLimit(1)
            Spacer()
            Button {
                isFavoritesPresented = true
            } label: {
                Image(systemName: "star")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "Station Info…"))
        }
    }

    private var stationTitle: String {
        if let favorite = viewModel.currentFavorite, !favorite.description.isEmpty {
            return favorite.description
        }
        return viewModel.band.stationLabel(for: viewModel.frequency)
    }
}

#Preview {
    ContentView(viewModel: RadioViewModel(), isFavoritesPresented: .constant(false))
}
