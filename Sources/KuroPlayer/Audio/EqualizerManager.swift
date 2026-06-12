import Foundation
import Combine

// MARK: - Models

struct EQBand: Codable, Equatable {
    enum FilterType: String, Codable, CaseIterable {
        case peak = "PK"
        case lowShelf = "LSC"
        case highShelf = "HSC"

        var label: String {
            switch self {
            case .peak: return "Peak"
            case .lowShelf: return "Low Shelf"
            case .highShelf: return "High Shelf"
            }
        }
    }

    var type: FilterType
    var frequency: Double // Hz
    var gain: Double      // dB
    var q: Double

    var frequencyLabel: String {
        frequency >= 1000
            ? String(format: "%.1fk", frequency / 1000)
            : String(format: "%.0f", frequency)
    }
}

struct EQPreset: Identifiable {
    let name: String
    let preamp: Double
    let bands: [EQBand]
    var id: String { name }
}

/// Realtime-safe value handed to the audio thread. Q is pre-converted to the
/// bandwidth (octaves) that the NBandEQ AudioUnit expects.
struct EQSnapshot: Sendable {
    static let maxBands = 16

    struct Band: Sendable {
        var filterType: Float // NBandEQ filter type constant
        var frequency: Float
        var gain: Float
        var bandwidth: Float  // octaves
    }

    var enabled: Bool
    var preamp: Float
    var bands: [Band]
}

// MARK: - Manager

/// Owns the user-facing EQ state. Presets are parametric EQ profiles in the
/// peqdb.com / AutoEq format (preamp + PK/LSC/HSC filters with Fc, gain, Q);
/// the bundled ones use oratory1990 measurement data. Any preset from
/// peqdb.com can be pasted in as text.
@MainActor
final class EqualizerManager: ObservableObject {
    static let shared = EqualizerManager()
    static let flatPresetName = "Flat"
    static let customPresetName = "Custom"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var preamp: Double
    @Published private(set) var bands: [EQBand]
    @Published private(set) var selectedPresetName: String

    private static let defaultsKey = "kuro_eq_settings_v1"

    private struct PersistedSettings: Codable {
        var enabled: Bool
        var preamp: Double
        var bands: [EQBand]
        var presetName: String
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(PersistedSettings.self, from: data) {
            isEnabled = saved.enabled
            preamp = saved.preamp
            bands = saved.bands
            selectedPresetName = saved.presetName
        } else {
            isEnabled = false
            preamp = 0
            bands = []
            selectedPresetName = Self.flatPresetName
        }
        pushSnapshot()
    }

    // MARK: Mutations

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        persistAndApply()
    }

    func setPreamp(_ value: Double) {
        preamp = value.clamped(to: -24...12)
        if selectedPresetName != Self.customPresetName { selectedPresetName = Self.customPresetName }
        persistAndApply()
    }

    func selectPreset(named name: String) {
        guard let preset = Self.presets.first(where: { $0.name == name }) else {
            selectedPresetName = Self.customPresetName
            persistAndApply()
            return
        }
        selectedPresetName = preset.name
        preamp = preset.preamp
        bands = preset.bands
        persistAndApply()
    }

    func setBandGain(at index: Int, gain: Double) {
        guard bands.indices.contains(index) else { return }
        bands[index].gain = gain.clamped(to: -24...24)
        if selectedPresetName != Self.customPresetName { selectedPresetName = Self.customPresetName }
        persistAndApply()
    }

    /// Imports a parametric EQ profile in the text format used by peqdb.com
    /// and AutoEq exports:
    ///
    ///     Preamp: -6.1 dB
    ///     Filter 1: ON LSC Fc 105 Hz Gain 6.4 dB Q 0.70
    ///
    /// Returns false if no filter lines could be parsed.
    @discardableResult
    func importParametricEQText(_ text: String) -> Bool {
        var parsedPreamp: Double = 0
        var parsedBands: [EQBand] = []

        for line in text.components(separatedBy: .newlines) {
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == ":" }).map(String.init)
            guard !tokens.isEmpty else { continue }

            if tokens[0].lowercased() == "preamp", tokens.count >= 2, let value = Double(tokens[1]) {
                parsedPreamp = value
                continue
            }

            guard tokens[0].lowercased() == "filter" else { continue }

            var type: EQBand.FilterType?
            var frequency: Double?
            var gain: Double?
            var q: Double?

            var index = 0
            while index < tokens.count {
                switch tokens[index].uppercased() {
                case "PK", "PEQ": type = .peak
                case "LSC", "LS", "LSQ": type = .lowShelf
                case "HSC", "HS", "HSQ": type = .highShelf
                case "FC":
                    if index + 1 < tokens.count { frequency = Double(tokens[index + 1]) }
                case "GAIN":
                    if index + 1 < tokens.count { gain = Double(tokens[index + 1]) }
                case "Q":
                    if index + 1 < tokens.count { q = Double(tokens[index + 1]) }
                default: break
                }
                index += 1
            }

            if let type, let frequency, let gain {
                parsedBands.append(EQBand(type: type, frequency: frequency, gain: gain, q: q ?? 0.7))
            }
        }

        guard !parsedBands.isEmpty else { return false }

        preamp = parsedPreamp
        bands = Array(parsedBands.prefix(EQSnapshot.maxBands))
        selectedPresetName = Self.customPresetName
        persistAndApply()
        return true
    }

    var presetNames: [String] {
        Self.presets.map(\.name)
    }

    // MARK: Persistence + audio bridge

    private func persistAndApply() {
        let settings = PersistedSettings(enabled: isEnabled, preamp: preamp, bands: bands, presetName: selectedPresetName)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        pushSnapshot()
    }

    private func pushSnapshot() {
        let snapshotBands = bands.prefix(EQSnapshot.maxBands).map { band in
            EQSnapshot.Band(
                filterType: band.type.nbandFilterType,
                frequency: Float(band.frequency.clamped(to: 20...20000)),
                gain: Float(band.gain.clamped(to: -24...24)),
                bandwidth: Float(Self.bandwidthInOctaves(q: band.q))
            )
        }
        let snapshot = EQSnapshot(enabled: isEnabled, preamp: Float(preamp), bands: Array(snapshotBands))
        EQSettingsBridge.shared.update(snapshot)
    }

    /// RBJ relation between Q and bandwidth in octaves:
    /// BW = (2 / ln 2) * asinh(1 / (2Q))
    static func bandwidthInOctaves(q: Double) -> Double {
        guard q > 0 else { return 5.0 }
        let bw = (2.0 / log(2.0)) * asinh(1.0 / (2.0 * q))
        return bw.clamped(to: 0.05...5.0)
    }

    // MARK: Bundled presets
    //
    // Parametric profiles in the peqdb.com / AutoEq format, derived from
    // oratory1990 measurements. Flat = EQ pass-through.

    static let presets: [EQPreset] = [
        EQPreset(name: flatPresetName, preamp: 0, bands: []),
        EQPreset(name: "Sennheiser HD 600", preamp: -6.3, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: 6.5, q: 0.70),
            EQBand(type: .peak, frequency: 125, gain: -2.7, q: 0.55),
            EQBand(type: .peak, frequency: 522, gain: 0.7, q: 1.02),
            EQBand(type: .peak, frequency: 1298, gain: -1.2, q: 2.14),
            EQBand(type: .peak, frequency: 2166, gain: 0.9, q: 3.32),
            EQBand(type: .peak, frequency: 3158, gain: -1.8, q: 3.67),
            EQBand(type: .peak, frequency: 5433, gain: -1.2, q: 5.70),
            EQBand(type: .peak, frequency: 6639, gain: 2.2, q: 5.82),
            EQBand(type: .peak, frequency: 8445, gain: 3.3, q: 1.61),
            EQBand(type: .highShelf, frequency: 10000, gain: -3.1, q: 0.70)
        ]),
        EQPreset(name: "Sennheiser HD 650", preamp: -6.1, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: 6.4, q: 0.70),
            EQBand(type: .peak, frequency: 37, gain: 0.7, q: 3.96),
            EQBand(type: .peak, frequency: 118, gain: -3.1, q: 0.50),
            EQBand(type: .peak, frequency: 587, gain: 0.4, q: 1.19),
            EQBand(type: .peak, frequency: 1227, gain: -1.2, q: 2.53),
            EQBand(type: .peak, frequency: 2055, gain: 1.2, q: 3.23),
            EQBand(type: .peak, frequency: 3169, gain: -1.7, q: 3.89),
            EQBand(type: .peak, frequency: 5332, gain: -1.1, q: 5.75),
            EQBand(type: .peak, frequency: 8800, gain: 5.1, q: 1.42),
            EQBand(type: .highShelf, frequency: 10000, gain: -2.1, q: 0.70)
        ]),
        EQPreset(name: "Sennheiser HD 560S", preamp: -6.6, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: 9.0, q: 0.70),
            EQBand(type: .peak, frequency: 54, gain: -5.4, q: 0.48),
            EQBand(type: .peak, frequency: 491, gain: 0.6, q: 1.23),
            EQBand(type: .peak, frequency: 1148, gain: -1.5, q: 2.38),
            EQBand(type: .peak, frequency: 1937, gain: 0.9, q: 3.93),
            EQBand(type: .peak, frequency: 4502, gain: -1.7, q: 6.00),
            EQBand(type: .peak, frequency: 5639, gain: -0.9, q: 6.00),
            EQBand(type: .peak, frequency: 7451, gain: 2.0, q: 3.91),
            EQBand(type: .peak, frequency: 8983, gain: 4.4, q: 2.63),
            EQBand(type: .highShelf, frequency: 10000, gain: -3.9, q: 0.70)
        ]),
        EQPreset(name: "Sony WH-1000XM4", preamp: -6.1, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: -4.2, q: 0.70),
            EQBand(type: .peak, frequency: 56, gain: 1.2, q: 1.19),
            EQBand(type: .peak, frequency: 143, gain: -5.2, q: 1.10),
            EQBand(type: .peak, frequency: 407, gain: 1.7, q: 3.14),
            EQBand(type: .peak, frequency: 576, gain: -1.2, q: 3.55),
            EQBand(type: .peak, frequency: 1007, gain: 1.0, q: 3.41),
            EQBand(type: .peak, frequency: 2289, gain: 6.1, q: 1.57),
            EQBand(type: .peak, frequency: 5144, gain: -3.2, q: 6.00),
            EQBand(type: .peak, frequency: 6715, gain: 3.0, q: 5.99),
            EQBand(type: .highShelf, frequency: 10000, gain: -1.0, q: 0.70)
        ]),
        EQPreset(name: "Sony WH-1000XM5", preamp: -6.2, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: -3.2, q: 0.70),
            EQBand(type: .peak, frequency: 63, gain: 0.4, q: 2.13),
            EQBand(type: .peak, frequency: 173, gain: -5.6, q: 0.96),
            EQBand(type: .peak, frequency: 875, gain: -1.2, q: 4.07),
            EQBand(type: .peak, frequency: 1197, gain: 1.0, q: 3.28),
            EQBand(type: .peak, frequency: 1327, gain: 3.3, q: 0.58),
            EQBand(type: .peak, frequency: 2448, gain: 6.9, q: 2.46),
            EQBand(type: .peak, frequency: 3028, gain: -5.4, q: 2.03),
            EQBand(type: .peak, frequency: 6110, gain: -2.3, q: 5.81),
            EQBand(type: .highShelf, frequency: 10000, gain: 4.9, q: 0.70)
        ]),
        EQPreset(name: "AKG K371", preamp: -5.6, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: -2.7, q: 0.70),
            EQBand(type: .peak, frequency: 67, gain: 3.1, q: 1.41),
            EQBand(type: .peak, frequency: 182, gain: -2.3, q: 1.23),
            EQBand(type: .peak, frequency: 524, gain: 0.3, q: 1.66),
            EQBand(type: .peak, frequency: 1066, gain: -0.8, q: 2.57),
            EQBand(type: .peak, frequency: 2048, gain: 0.5, q: 4.67),
            EQBand(type: .peak, frequency: 4038, gain: 5.0, q: 3.60),
            EQBand(type: .peak, frequency: 4232, gain: 0.9, q: 5.03),
            EQBand(type: .peak, frequency: 5564, gain: -1.6, q: 3.89),
            EQBand(type: .highShelf, frequency: 10000, gain: 2.4, q: 0.70)
        ]),
        EQPreset(name: "Audio-Technica ATH-M50x", preamp: -3.1, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: 0.6, q: 0.70),
            EQBand(type: .peak, frequency: 45, gain: -1.1, q: 1.90),
            EQBand(type: .peak, frequency: 66, gain: 1.4, q: 3.59),
            EQBand(type: .peak, frequency: 156, gain: -5.2, q: 0.73),
            EQBand(type: .peak, frequency: 326, gain: 5.3, q: 1.59),
            EQBand(type: .peak, frequency: 787, gain: -0.5, q: 1.79),
            EQBand(type: .peak, frequency: 1640, gain: 0.9, q: 3.41),
            EQBand(type: .peak, frequency: 3483, gain: 2.1, q: 5.82),
            EQBand(type: .peak, frequency: 7077, gain: 2.8, q: 2.22),
            EQBand(type: .highShelf, frequency: 10000, gain: -4.1, q: 0.70)
        ]),
        EQPreset(name: "7Hz Salnotes Zero", preamp: -2.5, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: -0.4, q: 0.70),
            EQBand(type: .peak, frequency: 65, gain: 1.7, q: 1.11),
            EQBand(type: .peak, frequency: 186, gain: -1.3, q: 1.35),
            EQBand(type: .peak, frequency: 857, gain: 0.9, q: 1.64),
            EQBand(type: .peak, frequency: 1261, gain: -0.7, q: 3.34),
            EQBand(type: .peak, frequency: 1677, gain: -1.1, q: 1.82),
            EQBand(type: .peak, frequency: 3316, gain: -0.6, q: 2.50),
            EQBand(type: .peak, frequency: 7148, gain: 2.5, q: 1.39),
            EQBand(type: .peak, frequency: 9824, gain: 0.9, q: 1.98),
            EQBand(type: .highShelf, frequency: 10000, gain: -1.3, q: 0.70)
        ])
    ]
}

private extension EQBand.FilterType {
    /// NBandEQ AudioUnit filter type constants
    /// (kAUNBandEQFilterType_Parametric / _LowShelf / _HighShelf).
    var nbandFilterType: Float {
        switch self {
        case .peak: return 0
        case .lowShelf: return 7
        case .highShelf: return 8
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
