import SwiftUI

struct NowPlayingIndicator: View {
    let isPlaying: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(KurokulaTheme.accent)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isPlaying else { return 4 }

        // Random-looking math to generate bouncing bars out of phase
        let base: CGFloat = 4
        let amplitude: CGFloat = 10
        let offset = CGFloat(index) * .pi / 3
        let sine = sin(phase * .pi * 4 + offset)
        return base + amplitude * abs(sine)
    }
}
