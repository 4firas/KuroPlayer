import SwiftUI

/// Horizontal capsule slider matching the Liquid Glass theme. Replaces the
/// stock AppKit slider, which clashed with the rest of the design.
/// Value is normalized 0...1; drag anywhere on the track to set it.
struct KuroSlider: View {
    @Binding var value: Double
    var onEditingEnded: (() -> Void)? = nil

    private let trackHeight: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(trackHeight, width * value.clamped(to: 0...1)), height: trackHeight)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        value = (gesture.location.x / width).clamped(to: 0...1)
                    }
                    .onEnded { _ in
                        onEditingEnded?()
                    }
            )
        }
        .frame(height: 16)
    }
}
