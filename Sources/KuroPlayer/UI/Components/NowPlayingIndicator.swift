import SwiftUI

struct NowPlayingIndicator: View {
    let isPlaying: Bool

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.accent)
                        .frame(width: 2, height: barHeight(for: index, time: t))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 4 }

        let base: CGFloat = 4
        let amplitude: CGFloat = 10
        let offset = CGFloat(index) * .pi / 3
        let phase = CGFloat(time).truncatingRemainder(dividingBy: 2.0)
        let sine = sin(phase * .pi * 4 + offset)
        return base + amplitude * abs(sine)
    }
}
