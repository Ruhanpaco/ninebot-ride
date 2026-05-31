//
//  Open_Ninebot_RideApp.swift
//  Open Ninebot Ride
//
//  Created by Ruhan Pacolli on 31.5.26.
//

import SwiftUI
import SwiftData

@main
struct Open_Ninebot_RideApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
