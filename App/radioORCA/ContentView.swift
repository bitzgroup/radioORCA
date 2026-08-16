import RadioSharkKit
import SwiftUI

/// Minimal placeholder from Phase 0/1, confirming that `RadioSharkKit` links
/// correctly into the app. The real UI (tuning, playback controls, etc.) is
/// built in Phase 3 — see docs/app-feature-spec.md / docs/implementation-plan.md.
///
/// UI strings are authored in English (the project's base language) and
/// localized into Japanese via the String Catalog (`Localizable.xcstrings`).
struct ContentView: View {
    private enum ConnectionStatus {
        case disconnected
        case connected
        case failed(String)
    }

    @State private var status: ConnectionStatus = .disconnected
    private let controller = HIDController()

    var body: some View {
        VStack(spacing: 16) {
            Text("radioORCA")
                .font(.title)
            statusText
                .foregroundStyle(.secondary)
            Button("Connect", action: connect)
        }
        .padding(40)
        .frame(minWidth: 320, minHeight: 200)
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .disconnected:
            Text("radioSHARK 2 not connected")
        case .connected:
            Text("Connected to radioSHARK 2")
        case .failed(let message):
            Text("Connection failed: \(message)")
        }
    }

    private func connect() {
        do {
            try controller.connect()
            status = .connected
        } catch {
            status = .failed("\(error)")
        }
    }
}

#Preview {
    ContentView()
}
