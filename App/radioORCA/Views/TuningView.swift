import SwiftUI

/// Tuning controls — AM/FM switch, Up/Down, slider, direct frequency entry
/// — per `docs/app-feature-spec.md` §1.1.
struct TuningView: View {
    @ObservedObject var viewModel: RadioViewModel
    @State private var directEntryText = ""
    @FocusState private var isDirectEntryFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker(String(localized: "Band"), selection: bandBinding) {
                    ForEach(RadioBand.allCases) { band in
                        Text(band.label).tag(band)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 160)

                // Region determines FM range/step and the AM step
                // (`docs/app-feature-spec.md` §4.2). A full Preferences
                // screen (Standard/Japanese, Odd/Even/All, 9/10kHz) is
                // Phase 5; this is the minimal control needed until then.
                Picker(String(localized: "Region"), selection: regionBinding) {
                    ForEach(TuningRegion.allCases) { region in
                        Text(region.label).tag(region)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 110)
            }

            HStack(spacing: 16) {
                Button(action: viewModel.tuneDown) {
                    Image(systemName: "minus")
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                .help(String(localized: "Tune Down"))

                VStack(spacing: 2) {
                    Text(viewModel.band.displayString(for: viewModel.frequency))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(unitLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 150)

                Button(action: viewModel.tuneUp) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                .help(String(localized: "Tune Up"))
            }
            .buttonStyle(.bordered)

            Slider(
                value: frequencyBinding,
                in: viewModel.band.range(for: viewModel.region),
                step: viewModel.band.tuneStep(for: viewModel.region)
            )
            .frame(maxWidth: 260)

            HStack(spacing: 6) {
                TextField(String(localized: "Enter frequency"), text: $directEntryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isDirectEntryFocused)
                    .onSubmit(applyDirectEntry)
                    .frame(maxWidth: 120)
                Text(unitLabel)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bandBinding: Binding<RadioBand> {
        Binding(get: { viewModel.band }, set: { viewModel.setBand($0) })
    }

    private var regionBinding: Binding<TuningRegion> {
        Binding(get: { viewModel.region }, set: { viewModel.region = $0 })
    }

    private var frequencyBinding: Binding<Double> {
        Binding(get: { viewModel.frequency }, set: { viewModel.setFrequency($0) })
    }

    private var unitLabel: String {
        viewModel.band == .fm ? String(localized: "MHz") : String(localized: "kHz")
    }

    private func applyDirectEntry() {
        defer { directEntryText = "" }
        guard let value = Double(directEntryText) else { return }
        viewModel.setFrequency(value)
    }
}

#Preview {
    TuningView(viewModel: RadioViewModel())
        .padding()
}
