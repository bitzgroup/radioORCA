import RadioSharkKit

/// App-level band identity, kept separate from `RadioSharkKit.Band` (whose
/// raw values are the protocol's wire bytes) so this type is free to be
/// `Codable`/`CaseIterable` for UI and `Favorite` persistence without
/// coupling the HID protocol layer to app concerns.
enum RadioBand: String, CaseIterable, Codable, Identifiable {
    case fm
    case am

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fm: return String(localized: "FM")
        case .am: return String(localized: "AM")
        }
    }

    var hidBand: Band {
        switch self {
        case .fm: return .fm
        case .am: return .am
        }
    }

    /// Tuning range and step depend on region — see `TuningRegion`.
    func range(for region: TuningRegion) -> ClosedRange<Double> {
        switch self {
        case .fm: return region.fmRange
        case .am: return region.amRange
        }
    }

    /// Step used by Tune Up/Down (arrow keys) and the tuning slider.
    func tuneStep(for region: TuningRegion) -> Double {
        switch self {
        case .fm: return region.fmStep
        case .am: return region.amStep
        }
    }

    func defaultFrequency(for region: TuningRegion) -> Double {
        range(for: region).lowerBound
    }

    func clamp(_ frequency: Double, for region: TuningRegion) -> Double {
        let range = range(for: region)
        return min(max(frequency, range.lowerBound), range.upperBound)
    }

    /// The frequency as a station label used in recording filenames and
    /// the Station Description (e.g. `"FM87.5"`, `"AM810"`).
    func stationLabel(for frequency: Double) -> String {
        switch self {
        case .fm: return "FM" + String(format: "%.1f", frequency)
        case .am: return "AM" + String(Int(frequency.rounded()))
        }
    }

    func displayString(for frequency: Double) -> String {
        switch self {
        case .fm: return String(format: "%.1f", frequency)
        case .am: return String(Int(frequency.rounded()))
        }
    }
}
