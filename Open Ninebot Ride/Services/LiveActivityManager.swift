import Foundation
import ActivityKit

@MainActor
class LiveActivityManager {
    private var activity: Activity<RideActivityAttributes>?
    private var startDate: Date = Date()

    func start(scooterName: String, speed: Double, mode: String, batteryLevel: Double) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RideActivityAttributes(
            scooterName: scooterName.isEmpty ? "Ninebot" : scooterName,
            startDate: Date()
        )
        startDate = Date()

        let state = RideActivityAttributes.ContentState(
            speed: speed,
            mode: mode,
            batteryLevel: batteryLevel,
            duration: 0,
            isRecording: true
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func update(speed: Double, mode: String, batteryLevel: Double) {
        guard let activity = activity else { return }

        let state = RideActivityAttributes.ContentState(
            speed: speed,
            mode: mode,
            batteryLevel: batteryLevel,
            duration: Date().timeIntervalSince(startDate),
            isRecording: true
        )

        Task {
            await activity.update(
                .init(state: state, staleDate: nil)
            )
        }
    }

    func end() {
        guard let activity = activity else { return }

        let state = RideActivityAttributes.ContentState(
            speed: 0,
            mode: "Off",
            batteryLevel: 0,
            duration: Date().timeIntervalSince(startDate),
            isRecording: false
        )

        Task {
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .default
            )
            self.activity = nil
        }
    }
}
