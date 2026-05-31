import SwiftUI

// MARK: - Flat Dark Background (no gradients)
struct AppBackground<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06)
            content
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card Style
struct AppCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Press Scale Button Style
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
