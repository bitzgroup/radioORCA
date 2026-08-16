import Foundation

/// FM/AM tuning range and step differ by region — the original radioSHARK
/// app modeled this explicitly (`docs/app-feature-spec.md` §4.2: "FM Tuning
/// range: Standard/Japanese", "AM tuning increment: 9kHz/10kHz";
/// `docs/hardware-protocol.md` §6). The device itself has no notion of
/// range or step — it's purely a host-side concern (§6: "デバイス側に範囲
/// や刻みの概念はない") — but getting it wrong means Tune Up/Down and the
/// slider can't actually land on real broadcast frequencies for the user's
/// region.
///
/// Phase 5 turns this into a user-facing Preferences toggle; for the
/// Phase 3 MVP it's inferred from the system region so it's still correct
/// out of the box without a settings screen.
enum TuningRegion: String, CaseIterable, Codable, Identifiable {
    case standard
    case japan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .japan: return String(localized: "Japan")
        }
    }

    /// FM channels are spaced 0.2MHz apart in the US ("Odd" tenths only —
    /// `docs/hardware-protocol.md` §6's Odd/Even/All setting is a further
    /// refinement left to Phase 5) and 0.1MHz apart in Japan.
    var fmStep: Double {
        switch self {
        case .standard: return 0.2
        case .japan: return 0.1
        }
    }

    var fmRange: ClosedRange<Double> {
        switch self {
        case .standard: return 87.5...107.9
        case .japan: return 76...89
        }
    }

    /// AM channels are on a 10kHz raster in the US, 9kHz in Japan/most of
    /// the rest of the world.
    var amStep: Double {
        switch self {
        case .standard: return 10
        case .japan: return 9
        }
    }

    var amRange: ClosedRange<Double> {
        530...1710
    }

    /// Inferred from the system region so the MVP (no Preferences screen
    /// yet) still defaults to frequencies that exist in the user's area.
    static var systemDefault: TuningRegion {
        Locale.current.region?.identifier == "JP" ? .japan : .standard
    }
}
