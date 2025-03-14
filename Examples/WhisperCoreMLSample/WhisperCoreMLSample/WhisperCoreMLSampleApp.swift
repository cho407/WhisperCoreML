//
//  WhisperCoreMLSampleApp.swift
//  WhisperCoreMLSample
//
//  Created by 조형구 on 3/14/25.
//

import SwiftUI

@main
struct WhisperCoreMLSampleApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
