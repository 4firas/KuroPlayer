import SwiftUI

// MARK: - KuroPlayer Icon Set

// MARK: - Rainbow Swirl

struct RainbowSwirlIcon: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Theme.accent,
                            Theme.secondary,
                            Theme.success,
                            Theme.accent
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: size * 0.18
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-30))

            ForEach(0..<3) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                [Theme.accent, .pink][i % 2],
                                [Theme.secondary, Theme.success][i % 2]
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.14, height: size * 0.36)
                    .offset(y: -size * 0.18)
                    .rotationEffect(.degrees(Double(i) * 120))
                    .blendMode(.screen)
                    .opacity(0.85)
            }

            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.16, height: size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Playlist Thumbnail

struct PlaylistThumbnail: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.55), tint.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - User Avatar

struct UserAvatar: View {
    let initial: String
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accentGradient)
            Text(initial)
                .font(.system(size: size * 0.46, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Kuro Brand Mark

struct KuroBrandMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accentGradient)
                .frame(width: 18, height: 18)
            Text("k")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .offset(y: 0.5)
        }
    }
}
