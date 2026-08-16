import SwiftUI

/// The Fin (USB connection) status indicator — `docs/app-feature-spec.md`
/// §1.3: "グレー：未接続 / 青：接続中 / 赤：接続中＋録音中".
struct FinIndicatorView: View {
    let state: FinState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
            .help(helpText)
            .accessibilityLabel(helpText)
    }

    private var color: Color {
        switch state {
        case .disconnected: return .gray
        case .connected: return .blue
        case .recording: return .red
        }
    }

    private var helpText: String {
        switch state {
        case .disconnected: return String(localized: "radioSHARK 2 not connected")
        case .connected: return String(localized: "radioSHARK 2 connected")
        case .recording: return String(localized: "radioSHARK 2 connected — recording")
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        FinIndicatorView(state: .disconnected)
        FinIndicatorView(state: .connected)
        FinIndicatorView(state: .recording)
    }
    .padding()
}
