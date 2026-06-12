import SwiftUI

class IndicatorState: ObservableObject {
    @Published var h1: CGFloat = 4
    @Published var h2: CGFloat = 4
    @Published var h3: CGFloat = 4
}

struct NowPlayingIndicator: View {
    let isPlaying: Bool
    @StateObject private var state = IndicatorState()

    var body: some View {
        HStack(spacing: 2) {
            bar(height: state.h1)
            bar(height: state.h2)
            bar(height: state.h3)
        }
        .frame(height: 16)
        .onAppear {
            if isPlaying { startAnimation() }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing { startAnimation() }
            else { stopAnimation() }
        }
    }
    
    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Theme.accent)
            .frame(width: 3, height: height)
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { state.h1 = 12 }
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { state.h2 = 16 }
        withAnimation(.easeInOut(duration: 0.30).repeatForever(autoreverses: true)) { state.h3 = 10 }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            state.h1 = 4
            state.h2 = 4
            state.h3 = 4
        }
    }
}
