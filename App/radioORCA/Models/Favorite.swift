import Foundation

/// A saved station (`docs/app-feature-spec.md` §2 "Station Info"). Icon
/// selection and Genre picklists are deferred past the Phase 3 MVP — see
/// the `docs/implementation-plan.md` Phase 3 checklist.
struct Favorite: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var band: RadioBand
    var frequency: Double
    var description: String
    var url: String = ""
    var phone: String = ""
    var genre: String = ""
    /// 1...9, matching the ⌘+1...⌘+9 preset shortcuts
    /// (`docs/app-feature-spec.md` §7). `nil` means "not pinned to a key".
    var presetKey: Int?

    var stationLabel: String {
        band.stationLabel(for: frequency)
    }
}
