import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scooterManager = ScooterManager()
    @State private var selectedTab: Tab = .connect

    enum Tab: String, CaseIterable {
        case connect = "connect"
        case dashboard = "dashboard"
        case map = "map"
        case history = "history"
        case more = "more"

        var icon: String {
            switch self {
            case .connect: return "antenna.radiowaves.left.and.right"
            case .dashboard: return "speedometer"
            case .map: return "map"
            case .history: return "clock.arrow.circlepath"
            case .more: return "ellipsis"
            }
        }

        var label: String {
            switch self {
            case .connect: return "Connect"
            case .dashboard: return "Dashboard"
            case .map: return "Map"
            case .history: return "History"
            case .more: return "More"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                tabContent
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    if !isLandscape {
                        tabBar
                    }
                }

                if isLandscape {
                    TwoFingerSwipeView(
                        onSwipeLeft: { moveToNextTab() },
                        onSwipeRight: { moveToPrevTab() }
                    )
                    .ignoresSafeArea()
                }
            }
        }
        .onAppear {
            scooterManager.setModelContext(modelContext)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .connect:
            ConnectView(scooterManager: scooterManager)
        case .dashboard:
            DashboardView(scooterManager: scooterManager)
        case .map:
            MapPage(scooterManager: scooterManager)
        case .history:
            RideHistoryView()
        case .more:
            SettingsView(scooterManager: scooterManager)
        }
    }

    private func moveToNextTab() {
        let allTabs = Tab.allCases
        guard let idx = allTabs.firstIndex(of: selectedTab), idx < allTabs.count - 1 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedTab = allTabs[idx + 1]
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func moveToPrevTab() {
        let allTabs = Tab.allCases
        guard let idx = allTabs.firstIndex(of: selectedTab), idx > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedTab = allTabs[idx - 1]
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases.indices, id: \.self) { index in
                let tab = Tab.allCases[index]
                let isActive = selectedTab == tab

                Button {
                    let impact = UIImpactFeedbackGenerator(style: .soft)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(.white.opacity(0.12))
                                    .frame(width: 40, height: 40)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: isActive ? 20 : 18, weight: isActive ? .semibold : .ultraLight))
                                .symbolVariant(isActive ? .fill : .none)
                                .foregroundStyle(isActive ? .white : .white.opacity(0.3))
                        }
                        Text(tab.label)
                            .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? .white.opacity(0.8) : .white.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TabButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Two-Finger Swipe Gesture
struct TwoFingerSwipeView: UIViewRepresentable {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false

        let left = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeLeft))
        left.direction = .left
        left.numberOfTouchesRequired = 2
        view.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeRight))
        right.direction = .right
        right.numberOfTouchesRequired = 2
        view.addGestureRecognizer(right)

        return view
    }

    func updateUIView(_: UIView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }

    class Coordinator: NSObject {
        let onSwipeLeft: () -> Void
        let onSwipeRight: () -> Void

        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
        }

        @objc func handleSwipeLeft() { onSwipeLeft() }
        @objc func handleSwipeRight() { onSwipeRight() }
    }
}
