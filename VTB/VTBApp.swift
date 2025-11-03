//
//  VTBApp.swift
//  VTB
//
//  Created by maksimchernukha on 03.11.2025.
//

import SwiftUI
import CoreData

@main
struct VTBApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
