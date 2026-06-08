//
//  DailySessionStore.swift
//  Patente-Learning
//
//  Persisted state for the daily "Today's Session" plan: chosen tier, prep
//  start date, today's sub-session progress, and the day streak. Exposes the
//  live readiness forecast (ready-date + on-track) for the home headline.
//
//  Date/streak rules live in DailySessionLogic (pure + tested). Persistence is
//  a single JSON blob in UserDefaults ("dailySessionState").
//

import Foundation
import Combine

final class DailySessionStore: ObservableObject {

    static let shared = DailySessionStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "dailySessionState"

    struct State: Codable {
        var tierRaw: String = SessionTier.fastTrack50.rawValue
        var prepStartDate: Date? = nil
        var lastActive: Date = .distantPast
        var subSessionsStored: Int = 0      // sub-sessions done on `lastActive`'s day
        var streak: Int = 0
        var lastGoalMetDay: Date? = nil
        var goalMetDaysTotal: Int = 0       // distinct days the goal was met (for cadence)
    }

    @Published private(set) var state: State { didSet { persist() } }

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Tier

    var goalTier: SessionTier {
        get { SessionTier(rawValue: state.tierRaw) ?? .fastTrack50 }
        set { state.tierRaw = newValue.rawValue }
    }

    var chunkSize: Int { goalTier.chunkSize }
    var chunkCount: Int { goalTier.chunkCount }

    // MARK: - Today

    var subSessionsToday: Int {
        DailySessionLogic.subSessionsToday(stored: state.subSessionsStored,
                                           lastActive: state.lastActive,
                                           now: Date())
    }

    var isGoalMetToday: Bool {
        DailySessionLogic.isGoalMet(subSessionsToday: subSessionsToday, chunkCount: chunkCount)
    }

    var remainingSubSessionsToday: Int { max(0, chunkCount - subSessionsToday) }

    /// Displayed streak (broken to 0 if a day was missed).
    var streak: Int {
        DailySessionLogic.displayedStreak(streak: state.streak,
                                          lastGoalMetDay: state.lastGoalMetDay,
                                          now: Date())
    }

    var hasStarted: Bool { state.prepStartDate != nil }

    // MARK: - Mutations

    /// Call when the learner finishes one sub-session (a chunk of the daily goal).
    func recordSubSessionCompleted(now: Date = Date()) {
        var s = state
        if s.prepStartDate == nil { s.prepStartDate = now }

        let todayCount = DailySessionLogic.subSessionsToday(stored: s.subSessionsStored,
                                                            lastActive: s.lastActive,
                                                            now: now)
        let wasGoalMet = DailySessionLogic.isGoalMet(subSessionsToday: todayCount, chunkCount: chunkCount)

        s.subSessionsStored = todayCount + 1
        s.lastActive = now

        let nowGoalMet = DailySessionLogic.isGoalMet(subSessionsToday: s.subSessionsStored, chunkCount: chunkCount)
        // Only advance the streak on the sub-session that *completes* the goal.
        if nowGoalMet && !wasGoalMet {
            let result = DailySessionLogic.streakOnGoalMet(streak: s.streak,
                                                           lastGoalMetDay: s.lastGoalMetDay,
                                                           now: now)
            s.streak = result.streak
            s.lastGoalMetDay = result.day
            s.goalMetDaysTotal += 1
        }
        state = s
    }

    func setTier(_ tier: SessionTier) { goalTier = tier }

    func reset() { state = State() }

    // MARK: - Forecast

    /// Live "exam-ready" projection for the home headline (current tier).
    func forecast(progress: ExamProgressManager = .shared,
                  store: BloccoStore = .shared,
                  now: Date = Date()) -> ReadinessForecast {
        forecast(for: goalTier, progress: progress, store: store, now: now)
    }

    /// Projection for an arbitrary tier — used by the Settings picker to show
    /// each option's ready-date against the learner's current progress.
    func forecast(for tier: SessionTier,
                  progress: ExamProgressManager = .shared,
                  store: BloccoStore = .shared,
                  now: Date = Date()) -> ReadinessForecast {
        ReadinessForecaster.forecast(
            startDate: state.prepStartDate ?? now,
            tier: tier,
            sessionsPerDay: observedCadence(now: now),
            progress: progress,
            store: store,
            now: now
        )
    }

    /// Goal-met days per elapsed calendar day since prep started, clamped to a
    /// sane range. Falls back to 1/day before any data exists.
    private func observedCadence(now: Date) -> Double {
        guard let start = state.prepStartDate else { return 1 }
        let elapsed = max(1, DailySessionLogic.daysBetween(start, now) + 1)
        let raw = Double(state.goalMetDaysTotal) / Double(elapsed)
        return raw <= 0 ? 1 : min(1.5, max(0.2, raw))
    }
}
