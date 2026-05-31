import SwiftUI
import SwiftData

@main
struct Open_Ninebot_RideApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Scooter.self,
            Ride.self,
            RidePoint.self,
            EventRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
