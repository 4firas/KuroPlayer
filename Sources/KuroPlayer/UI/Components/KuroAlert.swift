import SwiftUI

struct KuroAlert: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    cancelAction()
                }
                .transition(.opacity)

            // Alert Box
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain) // Removes native macOS focus ring
                    .padding(10)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1) // Kurokula focus hint
                    )

                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("Cancel") {
                        cancelAction()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button(primaryButtonTitle) {
                        primaryAction()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
            .frame(width: 360)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}
