import SwiftUI

/// Station Info + Favorites/Presets panel (`docs/app-feature-spec.md` §2:
/// Favorite/Description/URL/Phone/Genre/Preset Key). Icon selection is
/// deferred past the Phase 3 MVP.
struct FavoritesView: View {
    @ObservedObject var viewModel: RadioViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var url = ""
    @State private var phone = ""
    @State private var genre = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Station Info")
                .font(.title2.bold())

            currentStationForm

            Divider()

            Text("Favorites")
                .font(.headline)
            favoritesList

            HStack {
                Spacer()
                Button(String(localized: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 380)
        .onAppear(perform: loadCurrentFavorite)
        .onChange(of: viewModel.frequency) { _ in loadCurrentFavorite() }
        .onChange(of: viewModel.band) { _ in loadCurrentFavorite() }
    }

    private var currentStationForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.band.stationLabel(for: viewModel.frequency))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LabeledContent(String(localized: "Description")) {
                TextField(String(localized: "Station name"), text: $description)
            }
            LabeledContent("URL") {
                TextField("https://…", text: $url)
            }
            LabeledContent(String(localized: "Phone")) {
                TextField(String(localized: "Phone"), text: $phone)
            }
            LabeledContent(String(localized: "Genre")) {
                TextField(String(localized: "Genre"), text: $genre)
            }

            HStack {
                Spacer()
                Button(currentFavorite == nil ? String(localized: "Add to Favorites") : String(localized: "Update Favorite")) {
                    saveCurrentFavorite()
                }
                if let currentFavorite {
                    Button(String(localized: "Remove Favorite"), role: .destructive) {
                        viewModel.favoritesStore.remove(currentFavorite)
                    }
                }
            }
        }
    }

    private var favoritesList: some View {
        List {
            ForEach(sortedFavorites) { favorite in
                HStack {
                    VStack(alignment: .leading) {
                        Text(favorite.description.isEmpty ? favorite.stationLabel : favorite.description)
                        Text(favorite.stationLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    presetPicker(for: favorite)
                    Button {
                        viewModel.selectFavorite(favorite)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .frame(minHeight: 160)
    }

    private func presetPicker(for favorite: Favorite) -> some View {
        Picker(String(localized: "Preset Key"), selection: Binding(
            get: { favorite.presetKey ?? 0 },
            set: { newValue in
                if newValue == 0 {
                    var updated = favorite
                    updated.presetKey = nil
                    viewModel.favoritesStore.update(updated)
                } else {
                    viewModel.favoritesStore.assign(presetKey: newValue, to: favorite)
                }
            }
        )) {
            Text("—").tag(0)
            ForEach(1...9, id: \.self) { key in
                Text("⌘\(key)").tag(key)
            }
        }
        .labelsHidden()
        .frame(width: 70)
    }

    private var sortedFavorites: [Favorite] {
        viewModel.favoritesStore.favorites.sorted { lhs, rhs in
            let lhsKey = lhs.presetKey ?? .max
            let rhsKey = rhs.presetKey ?? .max
            if lhsKey != rhsKey { return lhsKey < rhsKey }
            return lhs.description < rhs.description
        }
    }

    private var currentFavorite: Favorite? {
        viewModel.currentFavorite
    }

    private func loadCurrentFavorite() {
        if let favorite = currentFavorite {
            description = favorite.description
            url = favorite.url
            phone = favorite.phone
            genre = favorite.genre
        } else {
            description = viewModel.band.stationLabel(for: viewModel.frequency)
            url = ""
            phone = ""
            genre = ""
        }
    }

    private func saveCurrentFavorite() {
        if var favorite = currentFavorite {
            favorite.description = description
            favorite.url = url
            favorite.phone = phone
            favorite.genre = genre
            viewModel.favoritesStore.update(favorite)
        } else {
            viewModel.favoritesStore.add(
                Favorite(
                    band: viewModel.band,
                    frequency: viewModel.frequency,
                    description: description,
                    url: url,
                    phone: phone,
                    genre: genre
                )
            )
        }
    }
}

#Preview {
    FavoritesView(viewModel: RadioViewModel())
}
