import Foundation

/// Persists `Favorite`s as JSON in `UserDefaults` (the list is small — at
/// most a handful of stations plus 9 presets — so a defaults-backed blob is
/// simpler than a file-based store for the MVP).
@MainActor
final class FavoritesStore: ObservableObject {
    private static let defaultsKey = "favorites"

    @Published private(set) var favorites: [Favorite] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ favorite: Favorite) {
        favorites.append(favorite)
        save()
    }

    func update(_ favorite: Favorite) {
        guard let index = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites[index] = favorite
        save()
    }

    func remove(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    func favorite(forPresetKey key: Int) -> Favorite? {
        favorites.first { $0.presetKey == key }
    }

    /// Assigns `key` to `favorite`, clearing it from whichever favorite
    /// previously held it (each preset key maps to at most one favorite).
    func assign(presetKey key: Int, to favorite: Favorite) {
        for index in favorites.indices where favorites[index].presetKey == key {
            favorites[index].presetKey = nil
        }
        guard let index = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites[index].presetKey = key
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return }
        favorites = (try? JSONDecoder().decode([Favorite].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
