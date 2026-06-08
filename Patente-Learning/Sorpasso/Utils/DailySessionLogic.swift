//
//  DailySessionLogic.swift
//  Patente-Learning
//
//  Pure date/streak rules behind the daily session. Foundation-only and
//  deterministic (dates + calendar in, values out) so the tricky rollover and
//  streak edge cases are unit-testable without app dependencies. DailySession
//  Store holds the persisted state and calls into these.
//

import Foundation

enum DailySessionLogic {

    /// Effective sub-sessions completed "today" — 0 if the stored count is
    /// carried over from a previous calendar day.
    static func subSessionsToday(stored: Int,
                                 lastActive: Date,
                                 now: Date,
                                 calendar: Calendar = .current) -> Int {
        calendar.isDate(lastActive, inSameDayAs: now) ? stored : 0
    }

    /// Whether the daily goal (all `chunkCount` sub-sessions) is met.
    static func isGoalMet(subSessionsToday: Int, chunkCount: Int) -> Bool {
        chunkCount > 0 && subSessionsToday >= chunkCount
    }

    /// Streak to display: intact only if the goal was last met today or
    /// yesterday; a missed day breaks it back to 0.
    static func displayedStreak(streak: Int,
                                lastGoalMetDay: Date?,
                                now: Date,
                                calendar: Calendar = .current) -> Int {
        guard streak > 0, let last = lastGoalMetDay else { return 0 }
        return daysBetween(last, now, calendar) <= 1 ? streak : 0
    }

    /// New (streak, lastGoalMetDay) when the goal is *newly* met at `now`.
    /// - same day  → unchanged (already counted)
    /// - next day  → +1
    /// - gap > 1   → restart at 1
    static func streakOnGoalMet(streak: Int,
                                lastGoalMetDay: Date?,
                                now: Date,
                                calendar: Calendar = .current) -> (streak: Int, day: Date) {
        let today = calendar.startOfDay(for: now)
        guard let last = lastGoalMetDay else { return (1, today) }
        switch daysBetween(last, now, calendar) {
        case 0:  return (max(streak, 1), today)
        case 1:  return (streak + 1, today)
        default: return (1, today)
        }
    }

    /// Whole calendar days from `a` to `b` (start-of-day to start-of-day).
    static func daysBetween(_ a: Date, _ b: Date, _ calendar: Calendar = .current) -> Int {
        let d1 = calendar.startOfDay(for: a)
        let d2 = calendar.startOfDay(for: b)
        return calendar.dateComponents([.day], from: d1, to: d2).day ?? 0
    }
}
