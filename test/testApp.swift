//
//  testApp.swift
//  test
//
//  Created by Rodolfo Antonio Zorrilla Pena on 12/05/2026.
//

import SwiftUI
import CoreData

@main
struct testApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
