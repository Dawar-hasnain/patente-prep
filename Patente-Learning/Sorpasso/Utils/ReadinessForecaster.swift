//
//  ReadinessForecaster.swift
//  Patente-Learning
//
//  Projects a *dynamic* "exam-ready" date for the daily-session plan. The date
//  is the home screen's headline metric, so it must be honest: it recomputes
//  from the learner's actual concept-mastery progress and their chosen pace,
//  and slides if they fall behind rather than promising a fixed day-1 date.
//
//  Model (concept-level — see ReadinessEngine):
//    • "Ready" ≈ having MASTERED `targetCoverage` of the ~716 concepts; at that
//      point ReadinessEngine's P(pass) clears the "Exam ready" band.
//    • Each completed session converts roughly `nominalMasteredPerSession(tier)`
//      not-yet-mastered concepts into mastered ones (new coverage + review).
//    • days-to-ready = remainingConcepts / perSession / sessionsPerDay.
//

import Foundation

/// The three study intensities. Larger tiers are split into shorter sub-sessions
/// so each sitting stays commute-sized and completion rate stays high.
enum SessionTier: String, CaseIterable, Identifiable {
    case relaxed30
    case standard40
    case fastTrack50

    var id: String { rawValue }

    /// Total questions per day.
    var dailyTotal: Int {
        switch self {
        case .relaxed30:  return 30
        case .standard40: return 40
        case .fastTrack50: return 50
        }
    }

    /// Size of each sub-session sitting.
    var chunkSize: Int {
        switch self {
        case .relaxed30:  return 30   // single block
        case .standard40: return 20   // 2 × 20
        case .fastTrack50: return 25  // 2 × 25
        }
    }

    var chunkCount: Int { dailyTotal / chunkSize }

    var title: String {
        switch self {
        case .relaxed30:  return "Relaxed"
        case .standard40: return "Standard"
        case .fastTrack50: return "Fast track"
        }
    }

    /// Short descriptor for the picker (the live date is shown separately).
    var detail: String {
        chunkCount > 1 ? "\(dailyTotal)/day · \(chunkCount) × \(chunkSize)" : "\(dailyTotal)/day"
    }
}

struct ReadinessForecast {
    /// Projected calendar date the learner reaches the "Exam ready" band.
    /// `nil` only if the bank is empty.
    let readyDate: Date?
    /// Completed sessions still needed at the current pace.
    let sessionsRemaining: Int
    /// Whether the projection is within slack of the tier's nominal plan.
    let onTrack: Bool
    /// Already at/over the readiness target.
    let isReady: Bool
}

enum ReadinessForecaster {

    /// Fraction of concepts that must be MASTERED to clear the readiness band.
    /// Derived from the binomial: with prior 0.65 and well-practised mastery,
    /// P(pass) ≥ 0.85 lands around ~85% concept mastery.
    static let targetCoverage = 0.85

    /// Newly-mastered concepts per completed session, by tier. Below the raw
    /// daily total because some slots are spent re-reviewing and a concept can
    /// take more than one exposure to stick. Calibrated to the ~3–4 / 4–5 / 6
    /// week windows for Fast track / Standard / Relaxed.
    static func nominalMasteredPerSession(_ tier: SessionTier) -> Double {
        Double(tier.dailyTotal) * 0.45
    }

    /// Project the ready-date.
    /// - Parameter sessionsPerDay: observed recent cadence (defaults to 1).
    static func forecast(
        startDate: Date,
        tier: SessionTier,
        sessionsPerDay: Double = 1,
        progress: ExamProgressManager = .shared,
        store: BloccoStore = .shared,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReadinessForecast {
        let conceptTotal = store.conceptCount
        guard conceptTotal > 0 else {
            return ReadinessForecast(readyDate: nil, sessionsRemaining: 0, onTrack: true, isReady: false)
        }

        let target = Int((Double(conceptTotal) * targetCoverage).rounded(.up))
        let mastered = progress.masteredConceptCount(of: store)

        if mastered >= target {
            return ReadinessForecast(readyDate: now, sessionsRemaining: 0, onTrack: true, isReady: true)
        }

        let perSession = max(1.0, nominalMasteredPerSession(tier))
        let cadence = max(0.1, sessionsPerDay)

        let remaining = target - mastered
        let sessionsRemaining = Int((Double(remaining) / perSession).rounded(.up))
        let daysRemaining = Int((Double(sessionsRemaining) / cadence).rounded(.up))
        let readyDate = calendar.date(byAdding: .day, value: daysRemaining, to: now)

        // Nominal plan: full target from the start date at this tier's pace.
        let nominalSessions = Int((Double(target) / perSession).rounded(.up))
        let nominalDays = Int((Double(nominalSessions) / cadence).rounded(.up))
        let nominalReady = calendar.date(byAdding: .day, value: nominalDays, to: startDate) ?? now
        let slack: TimeInterval = 3 * 86_400   // 3-day grace before "behind"
        let onTrack = (readyDate ?? now) <= nominalReady.addingTimeInterval(slack)

        return ReadinessForecast(
            readyDate: readyDate,
            sessionsRemaining: sessionsRemaining,
            onTrack: onTrack,
            isReady: false
        )
    }
}
