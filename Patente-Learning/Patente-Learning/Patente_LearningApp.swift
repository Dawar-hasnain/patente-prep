//
//  Patente_LearningApp.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import SwiftUI

@main
struct Patente_LearningApp: App {
    
    init() {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { success, error in
                if success {
                    print("✅ Notification permission granted")
                } else if let error = error {
                    print("❌ Notification error:", error.localizedDescription)
                }
            }
        }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.none) // respects system mode
                .background(Color.appBackground)
        }
    }
}
