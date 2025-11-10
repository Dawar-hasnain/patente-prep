//
//  NotificationManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import UserNotifications
import Foundation

final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // 🔹 Request authorization manually if needed
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error:", error.localizedDescription)
            } else {
                print("Permission granted:", granted)
            }
        }
    }

    // 🔹 Schedule a one-time notification
    func scheduleNotification(title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification:", error.localizedDescription)
            } else {
                print("✅ Notification scheduled in \(seconds)s: \(title)")
            }
        }
    }

    // 🔹 Cancel all pending notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
