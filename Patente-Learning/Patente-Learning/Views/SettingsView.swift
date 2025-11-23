//
//  SettingsView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("accentColor") private var accentColorName: String = ThemeColor.Blue.rawValue
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Display Preferences
                Section(header: Text("Display")) {
                    Toggle(isOn: $isDarkMode) {
                        Label("Dark Mode", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                    }
                    .onChange(of: isDarkMode) { newValue in
                        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = newValue ? .dark : .light
                    }
                }
                
                // MARK: - Notifications
                Section(header: Text("Notifications")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Daily Motivation Reminder", systemImage: "bell.fill")
                    }
                    .onChange(of: notificationsEnabled) { enabled in
                        if enabled {
                            scheduleNotification()
                        } else {
                            removePendingNotifications()
                        }
                    }
                }
                
                // MARK: - App Info
                Section(header: Text("About")) {
                    Label("Version 1.0.0", systemImage: "info.circle.fill")
                    Label("Made with ❤️ for Patente Learners", systemImage: "car.fill")
                }
            }
            .navigationTitle("Settings")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("Done") { dismiss() }
//                }
//            }
        }
    }
    
    // MARK: - Notification Helpers
    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "🚗 Patente Reminder"
            content.body = "Review a few words today to keep your streak alive!"
            content.sound = .default
            
            var dateComponents = DateComponents()
            dateComponents.hour = 19  // 7 PM reminder
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    private func removePendingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
}
