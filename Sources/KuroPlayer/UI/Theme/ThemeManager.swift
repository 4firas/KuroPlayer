import SwiftUI

/// App-wide appearance state.
///
/// Two modes:
/// - `.system` — fully follows macOS: light/dark from the system setting and
///   the user's chosen system accent color.
/// - `.kurokula` — the original KuroPlayer look: forced dark with the
///   Kurokula palette. This is the default, and once switched away it can
///   only be brought back through the hidden switch in Settings → About
///   (click the version number seven times).
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    enum Mode: String, CaseIterable, Identifiable {
        case system
        case kurokula

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "System"
            case .kurokula: return "Kurokula"
            }
        }
    }

    @Published private(set) var mode: Mode
    @Published private(set) var kurokulaUnlocked: Bool
    /// Set briefly after the easter egg fires, so Settings can show a wink.
    @Published private(set) var justUnlocked = false

    private var secretTapCount = 0
    private static let modeKey = "kuro_theme_mode"
    private static let unlockedKey = "kuro_kurokula_unlocked"
    private static let tapsToUnlock = 7

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: Self.modeKey).flatMap(Mode.init(rawValue:))
        // Kurokula is the shipped default.
        mode = savedMode ?? .kurokula
        kurokulaUnlocked = UserDefaults.standard.bool(forKey: Self.unlockedKey)
    }

    func setMode(_ newMode: Mode) {
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Self.modeKey)
    }

    /// Modes offered in Settings. Kurokula only appears while it's active or
    /// after it has been unlocked via the easter egg.
    var availableModes: [Mode] {
        if kurokulaUnlocked || mode == .kurokula {
            return [.system, .kurokula]
        }
        return [.system]
    }

    /// Easter egg: seven clicks on the version number in Settings → About
    /// permanently unlocks the Kurokula scheme switch.
    func registerSecretTap() {
        guard !kurokulaUnlocked else { return }
        secretTapCount += 1
        if secretTapCount >= Self.tapsToUnlock {
            kurokulaUnlocked = true
            justUnlocked = true
            UserDefaults.standard.set(true, forKey: Self.unlockedKey)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self.justUnlocked = false
            }
        }
    }

    // MARK: - Palette

    /// nil = follow the system light/dark setting.
    var colorScheme: ColorScheme? {
        mode == .kurokula ? .dark : nil
    }

    /// Primary accent. In system mode this is the accent color the user
    /// picked in System Settings → Appearance.
    var accent: Color {
        mode == .kurokula ? KurokulaTheme.accent : .accentColor
    }

    /// Secondary highlight (neon yellow in Kurokula).
    var secondaryAccent: Color {
        mode == .kurokula ? KurokulaTheme.secondary : .accentColor
    }

    var success: Color {
        mode == .kurokula ? KurokulaTheme.success : .green
    }

    var error: Color {
        mode == .kurokula ? KurokulaTheme.error : .red
    }

    /// Base background used in hero gradients.
    var heroBackground: Color {
        mode == .kurokula ? KurokulaTheme.background : Color(nsColor: .windowBackgroundColor)
    }
}
