import SwiftUI
import AppKit

/// Settings section for the parametric EQ. Presets use the peqdb.com /
/// AutoEq parametric format; any preset can be copied from peqdb.com and
/// pasted in directly.
struct EqualizerSettingsSection: View {
    @ObservedObject private var eq = EqualizerManager.shared
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Equalizer")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: enabledBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Parametric EQ")
                            .font(.headline)
                        Text("Applied to the current track in real time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Divider()

                // Preset picker
                HStack {
                    Text("Headphone preset")
                        .font(.body)
                    Spacer()
                    KuroDropdown(
                        selection: presetBinding,
                        options: eq.presetNames + [EqualizerManager.customPresetName]
                    )
                    .frame(maxWidth: 280)
                }

                // Preamp
                HStack(spacing: 12) {
                    Text("Preamp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .leading)

                    KuroSlider(value: preampBinding)

                    Text(String(format: "%+.1f dB", eq.preamp))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
                .disabled(!eq.isEnabled)
                .opacity(eq.isEnabled ? 1 : 0.5)

                // Bands
                if !eq.bands.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(eq.bands.enumerated()), id: \.offset) { index, band in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(band.frequencyLabel) Hz")
                                        .font(.caption.monospaced())
                                    Text(band.type.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 64, alignment: .leading)

                                KuroSlider(value: bandGainBinding(at: index))

                                Text(String(format: "%+.1f dB", band.gain))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 64, alignment: .trailing)
                            }
                        }
                    }
                    .disabled(!eq.isEnabled)
                    .opacity(eq.isEnabled ? 1 : 0.5)
                }

                Divider()

                // peqdb.com integration
                HStack(spacing: 12) {
                    Button {
                        pastePreset()
                    } label: {
                        Label("Paste Preset", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(FlatButtonStyle())
                    .help("Paste a parametric EQ profile copied from peqdb.com or AutoEq")

                    Spacer()

                    Link("Find presets for your headphones at peqdb.com",
                         destination: URL(string: "https://peqdb.com")!)
                        .font(.caption)
                }
            }
            .padding()
            .glassCard(cornerRadius: 12)
        }
    }

    // MARK: - Bindings

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { eq.isEnabled },
            set: { eq.setEnabled($0) }
        )
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: { eq.selectedPresetName },
            set: { eq.selectPreset(named: $0) }
        )
    }

    /// Preamp mapped from -24...+12 dB to the slider's 0...1.
    private var preampBinding: Binding<Double> {
        Binding(
            get: { (eq.preamp + 24) / 36 },
            set: { eq.setPreamp($0 * 36 - 24) }
        )
    }

    /// Band gain mapped from -12...+12 dB to the slider's 0...1.
    private func bandGainBinding(at index: Int) -> Binding<Double> {
        Binding(
            get: {
                guard eq.bands.indices.contains(index) else { return 0.5 }
                return ((eq.bands[index].gain + 12) / 24).clamped(to: 0...1)
            },
            set: { eq.setBandGain(at: index, gain: $0 * 24 - 12) }
        )
    }

    private func pastePreset() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            viewModel.errorMessage = "Clipboard is empty."
            return
        }
        if !eq.importParametricEQText(text) {
            viewModel.errorMessage = "Couldn't read a parametric EQ profile from the clipboard. Copy the preset text from peqdb.com (Preamp + Filter lines) and try again."
        }
    }
}

class DropdownState: ObservableObject {
    @Published var isExpanded = false
}

struct KuroDropdown: View {
    @Binding var selection: String
    let options: [String]
    @StateObject private var state = DropdownState()

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    state.isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(selection)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                if state.isExpanded {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 36)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(options, id: \.self) { option in
                                    DropdownItemView(
                                        option: option,
                                        selection: $selection,
                                        isExpanded: $state.isExpanded
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .zIndex(100)
                }
            }
        }
    }
}

class DropdownItemState: ObservableObject {
    @Published var isHovered = false
}

struct DropdownItemView: View {
    let option: String
    @Binding var selection: String
    @Binding var isExpanded: Bool
    @StateObject private var state = DropdownItemState()
    
    var body: some View {
        Button(action: {
            selection = option
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isExpanded = false
            }
        }) {
            HStack {
                Text(option)
                    .foregroundColor(selection == option ? Theme.accent : .primary)
                Spacer()
                if selection == option {
                    Image(systemName: "checkmark")
                        .foregroundColor(Theme.accent)
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(state.isHovered ? Color.white.opacity(0.1) : Color.clear)
            .onHover { state.isHovered = $0 }
        }
        .buttonStyle(.plain)
    }
}
