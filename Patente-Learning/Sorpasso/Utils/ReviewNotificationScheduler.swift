//
//  ReviewNotificationScheduler.swift
//  Patente-Learning
//
//  Schedules the daily reminder with content composed from the learner's live
//  state — due-for-review count, streak, and the exam-ready forecast — instead
//  of a generic "review some words" string. HIG: notifications should be
//  specific and actionable.
//
//  The trigger repeats daily at the chosen hour; content is refreshed (the
//  request is replaced) on launch, when the user changes settings, and when the
//  app backgrounds, so the copy stays current with real progress.
//

import Foundation
import UserNotifications

enum ReviewNotificationScheduler {

    static let reminderID = "dailyReviewReminder"

    // Default keys/values mirror SettingsView's @AppStorage.
    static var isEnabledDefault: Bool { UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true }
    static var reminderHourDefault: Int { UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 19 }

    /// (Re)schedule the daily reminder. Safe to call repeatedly.
    static func refresh(enabled: Bool,
                        hour: Int,
                        progress: ExamProgressManager = .shared,
                        sessions: DailySessionStore = .shared) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard enabled else { return }

        let content = makeContent(progress: progress, sessions: sessions)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Convenience: refresh using the persisted settings.
    static func refreshFromSettings(progress: ExamProgressManager = .shared,
                                    sessions: DailySessionStore = .shared) {
        refresh(enabled: isEnabledDefault, hour: reminderHourDefault, progress: progress, sessions: sessions)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    // MARK: - Content

    private static func makeContent(progress: ExamProgressManager,
                                    sessions: DailySessionStore) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default

        let streak = sessions.streak
        let dueCount = progress.dueOrWeakCoreIDs().count

        if !sessions.hasStarted {
            content.title = "Start your patente prep 🚗"
            content.body  = "Your first session is ready — \(sessions.chunkSize) questions to get going."
        } else if streak > 0 && !sessions.isGoalMetToday {
            content.title = "Keep your \(streak)-day streak 🔥"
            content.body  = dueCount > 0
                ? "\(dueCount) question\(plural(dueCount)) due for review today\(readyClause(sessions))."
                : "Today's session keeps you on track\(readyClause(sessions))."
        } else if dueCount > 0 {
            content.title = "🚗 \(dueCount) question\(plural(dueCount)) due"
            content.body  = "A quick review session keeps your readiness climbing\(readyClause(sessions))."
        } else {
            content.title = "Time for today's session 🚗"
            content.body  = "Keep moving toward exam-ready\(readyClause(sessions))."
        }
        return content
    }

    private static func plural(_ n: Int) -> String { n == 1 ? "" : "s" }

    private static func readyClause(_ sessions: DailySessionStore) -> String {
        let forecast = sessions.forecast()
        if forecast.isReady { return " — you're exam ready!" }
        if let date = forecast.readyDate {
            return " — on track for \(date.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return ""
    }
}
