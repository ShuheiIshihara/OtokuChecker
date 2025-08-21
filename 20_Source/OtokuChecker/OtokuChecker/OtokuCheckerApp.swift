//
//  OtokuCheckerApp.swift
//  OtokuChecker
//
//  Created by 石原脩平 on 2025/08/19.
//

import SwiftUI

@main
struct OtokuCheckerApp: App {
    let persistenceController = PersistenceController.shared
    let diContainer = DIContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .diContainer(diContainer)
        }
    }
}
