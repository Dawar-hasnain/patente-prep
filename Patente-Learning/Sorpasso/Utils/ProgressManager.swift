//
//  ProgressManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import Foundation

// MARK: – Review Checkpoint Model
struct ReviewCheckpoint: Codable, Identifiable {
    var id = UUID()
    var section: Int                 // 1-10
    var completed: Bool
    var scheduledDate: Date?
    var lastScore: Double?
}

// MARK: – Memory Model
struct WordMemoryState: Codable, Identifiable {
    var id = UUID()
    var word: String
    var lastReviewed: Date
    var confidence: Double        // 0.0 – 1.0
    var correctCount: Int
    var incorrectCount: Int

    mutating func updatePerformance(correct: Bool) {
        lastReviewed = Date()
        if correct {
            correctCount += 1
            confidence = min(1.0, confidence + 0.15)
        } else {
            incorrectCount += 1
            confidence = max(0.0, confidence - 0.20)
        }
    }

    mutating func applyDecay() {
        let hours = abs(lastReviewed.timeIntervalSinceNow) / 3600
        let decay = hours / 200.0
        confidence = max(0.0, confidence - decay)
    }
}

final class ProgressManager {
    // MARK: - Singleton
    static let shared = ProgressManager()
    private init() {}

    // MARK: - Keys
    private let defaults = UserDefaults.standard
    private let reviewKeyPrefix = "reviewCheckpoints_"
    private let memoryKey = "wordMemoryStates"
    private let learningActivityKey = "learningActivity"

    // MARK: - Configurable Retry Interval
    #if DEBUG
    private let reviewRetryInterval: TimeInterval = 60 // 1 min
    #else
    private let reviewRetryInterval: TimeInterval = 24 * 60 * 60
    #endif

    // MARK: - Retrieve or Initialize Review Checkpoints
    func reviewCheckpoints(for chapter: ChapterList) -> [ReviewCheckpoint] {
        let key = reviewKeyPrefix + chapter.rawValue

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ReviewCheckpoint].self, from: data) {
            return decoded
        }

        // Initialize 10 empty checkpoints
        let blank = (1...10).map {
            ReviewCheckpoint(section: $0, completed: false, scheduledDate: nil, lastScore: nil)
        }
        saveCheckpoints(blank, for: chapter)
        return blank
    }

    func saveCheckpoints(_ checkpoints: [ReviewCheckpoint], for chapter: ChapterList) {
        let key = reviewKeyPrefix + chapter.rawValue
        if let data = try? JSONEncoder().encode(checkpoints) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Update a Single Checkpoint (with Cooldown)
    func updateCheckpoint(
        for chapter: ChapterList,
        section: Int,
        passed: Bool,
        score: Double
    ) {
        var checkpoints = reviewCheckpoints(for: chapter)
        guard let index = checkpoints.firstIndex(where: { $0.section == section }) else { return }

        if passed {
            checkpoints[index].completed = true
            checkpoints[index].scheduledDate = nil
        } else {
            checkpoints[index].completed = false
            checkpoints[index].lastScore = score
            checkpoints[index].scheduledDate = Date().addingTimeInterval(reviewRetryInterval)

            // 🔔 Local notification about retry
            NotificationManager.shared.scheduleNotification(
                title: "Review Ready",
                body: "Your retry for \(chapter.title) is available!",
                after: reviewRetryInterval
            )
        }

        saveCheckpoints(checkpoints, for: chapter)
    }

    // MARK: - Detect Pending Reviews (fixed logic)
    func nextPendingCheckpoint(for chapter: ChapterList) -> ReviewCheckpoint? {
        let cps = reviewCheckpoints(for: chapter)
        let now = Date()

        for cp in cps {
            guard cp.completed == false else { continue }

            if let scheduled = cp.scheduledDate {
                if scheduled <= now {
                    return cp
                }
            }
        }

        return nil
    }


    func nextPendingReview() -> (chapter: ChapterList, checkpoint: ReviewCheckpoint)? {
        for chapter in ChapterList.allCases {
            if let pending = nextPendingCheckpoint(for: chapter) {
                return (chapter, pending)
            }
        }
        return nil
    }

    // MARK: - Adaptive Passing Thresholds
    func passingThreshold(for progress: Double) -> Double {
        switch progress {
        case 0.0..<0.3: return 0.60
        case 0.3..<0.7: return 0.75
        case 0.7..<0.9: return 0.85
        default:        return 0.90
        }
    }

    func currentSection(for progress: Double) -> Int {
        return min(9, Int(progress * 10))
    }

    // MARK: - Chapter Progress
    func progress(for chapter: ChapterList) -> Double {
        let learned = defaults.stringArray(forKey: "learnedWords") ?? []
        let words = loadChapter(chapter.filename).words

        if words.isEmpty { return 0 }

        let count = words.filter { learned.contains($0.italian) }.count
        return Double(count) / Double(words.count)
    }

    func minimumReviewThreshold(for chapter: ChapterList) -> Double {
        let count = loadChapter(chapter.filename).words.count

        if count < 30 { return 0.30 }
        else if count < 100 { return 0.20 }
        else { return 0.10 }
    }

    // MARK: - Daily Learning Log
    func logDailyLearningActivity() {
        let key = formattedDateKey(for: Date())
        var activity = defaults.dictionary(forKey: learningActivityKey) as? [String: Int] ?? [:]
        activity[key, default: 0] += 1
        defaults.set(activity, forKey: learningActivityKey)
    }

    func weeklyActivity() -> [DailyActivity] {
        var result: [DailyActivity] = []
        let today = Date()

        let log = defaults.dictionary(forKey: learningActivityKey) as? [String: Int] ?? [:]

        for i in (0..<7).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let key = formattedDateKey(for: date)
            result.append(DailyActivity(date: key, wordsLearned: log[key] ?? 0))
        }
        return result
    }

    func resetWeeklyActivity() {
        defaults.removeObject(forKey: learningActivityKey)
    }

    private func formattedDateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Word Memory / Spaced Repetition Engine
    func loadMemoryStates() -> [WordMemoryState] {
        if let data = defaults.data(forKey: memoryKey),
           let decoded = try? JSONDecoder().decode([WordMemoryState].self, from: data) {
            return decoded
        }
        return []
    }

    func saveMemoryStates(_ states: [WordMemoryState]) {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: memoryKey)
        }
    }

    func updateMemoryState(for word: String, correct: Bool) {
        var states = loadMemoryStates()

        if let idx = states.firstIndex(where: { $0.word == word }) {
            states[idx].updatePerformance(correct: correct)
        } else {
            var new = WordMemoryState(
                word: word,
                lastReviewed: Date(),
                confidence: correct ? 0.5 : 0.3,
                correctCount: 0,
                incorrectCount: 0
            )
            new.updatePerformance(correct: correct)
            states.append(new)
        }
        saveMemoryStates(states)
    }
    // MARK: - Next Review Date (Adaptive)
    func nextReviewDate(for word: String) -> Date {
        let states = loadMemoryStates()
        guard let state = states.first(where: { $0.word == word }) else {
            return Date().addingTimeInterval(6 * 3600)
        }

        let baseInterval: TimeInterval
        switch state.confidence {
        case 0.0..<0.3: baseInterval = 6 * 3600     // 6 hours
        case 0.3..<0.6: baseInterval = 12 * 3600    // 12 hours
        case 0.6..<0.8: baseInterval = 24 * 3600    // 1 day
        default:        baseInterval = 48 * 3600    // 2 days
        }

        let jitter = Double.random(in: -0.1...0.1) * baseInterval
        return state.lastReviewed.addingTimeInterval(baseInterval + jitter)
    }

    // MARK: - Weak Words (Full WordMemoryState)
    func weakWords(threshold: Double = 0.5, limit: Int = 10) -> [WordMemoryState] {
        var states = loadMemoryStates()
        for i in 0..<states.count { states[i].applyDecay() }
        saveMemoryStates(states)

        return states
            .filter { $0.confidence < threshold }
            .sorted(by: { $0.confidence < $1.confidence })
            .prefix(limit)
            .map { $0 }
    }

    // Synonym for UI
    func weakMemoryWords(threshold: Double = 0.5, limit: Int = 10) -> [WordMemoryState] {
        return weakWords(threshold: threshold, limit: limit)
    }

    /// Returns all stored memory states — used by ExerciseEngine to route exercise difficulty.
    func allMemoryStates() -> [WordMemoryState] {
        return loadMemoryStates()
    }

    // MARK: - Translation Lookup
    func translation(for word: String) -> String? {
        for chapter in ChapterList.allCases {
            let words = loadChapter(chapter.filename).words
            if let entry = words.first(where: { $0.italian == word }) {
                return entry.english
            }
        }
        return nil
    }

    // MARK: - Chapter Mastery
    struct ChapterMastery: Codable {
        let chapter: ChapterList
        var isMastered: Bool
        var lastReviewed: Date?
        var score: Double?
    }

    func markChapterAsMastered(_ chapter: ChapterList, score: Double) {
        let key = "mastery_" + chapter.rawValue
        let record = ChapterMastery(
            chapter: chapter,
            isMastered: true,
            lastReviewed: Date(),
            score: score
        )
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: key)
        }
    }

    func isChapterMastered(_ chapter: ChapterList) -> Bool {
        let key = "mastery_" + chapter.rawValue
        guard let data = defaults.data(forKey: key),
              let record = try? JSONDecoder().decode(ChapterMastery.self, from: data)
        else { return false }
        return record.isMastered
    }

    func hasAttemptedFinalReview(_ chapter: ChapterList) -> Bool {
        let key = "mastery_" + chapter.rawValue
        guard let data = defaults.data(forKey: key),
              let record = try? JSONDecoder().decode(ChapterMastery.self, from: data)
        else { return false }
        return record.score != nil
    }

    // MARK: - Analytics Extensions
    func totalLearnedWords() -> Int {
        return defaults.stringArray(forKey: "learnedWords")?.count ?? 0
    }

    func totalChaptersMastered() -> Int {
        return ChapterList.allCases.filter { isChapterMastered($0) }.count
    }

    func averageScore() -> Double {
        let scores = ChapterList.allCases.compactMap { chapter -> Double? in
            let key = "mastery_" + chapter.rawValue
            guard let data = defaults.data(forKey: key),
                  let record = try? JSONDecoder().decode(ChapterMastery.self, from: data),
                  let score = record.score else { return nil }
            return score
        }

        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    func lastActiveDate() -> Date? {
        return defaults.object(forKey: "lastActiveDate") as? Date
    }

    func updateLastActiveDate() {
        defaults.set(Date(), forKey: "lastActiveDate")
    }

    // MARK: - Streak System
    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var current = defaults.integer(forKey: "currentStreak")
        var best = defaults.integer(forKey: "bestStreak")
        let last = defaults.object(forKey: "lastActiveDate") as? Date

        if let lastDay = last.map({ calendar.startOfDay(for: $0) }) {
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if diff == 0 {
                return  // same day
            } else if diff == 1 {
                current += 1
            } else {
                current = 1  // reset streak
            }
        } else {
            current = 1  // first day
        }

        best = max(best, current)
        defaults.set(current, forKey: "currentStreak")
        defaults.set(best, forKey: "bestStreak")
        defaults.set(today, forKey: "lastActiveDate")
    }

    func currentStreak() -> Int { defaults.integer(forKey: "currentStreak") }
    func bestStreak() -> Int { defaults.integer(forKey: "bestStreak") }

    func averageRecallAccuracy() -> Double {
        return defaults.double(forKey: "averageRecallAccuracy").clamped(to: 0...1)
    }

    // MARK: - Unlock Everything (Testing)
    func unlockAllChaptersForTesting() {
        var allWords: [String] = []

        for chapter in ChapterList.allCases {
            let words = loadChapter(chapter.filename).words.map { $0.italian }
            allWords.append(contentsOf: words)

            // Mark as mastered
            let record = ChapterMastery(
                chapter: chapter,
                isMastered: true,
                lastReviewed: Date(),
                score: 1.0
            )
            if let data = try? JSONEncoder().encode(record) {
                defaults.set(data, forKey: "mastery_" + chapter.rawValue)
            }

            // Mark all checkpoints as completed
            let cps = (1...10).map {
                ReviewCheckpoint(section: $0, completed: true, scheduledDate: nil, lastScore: 1.0)
            }
            saveCheckpoints(cps, for: chapter)
        }

        defaults.set(allWords, forKey: "learnedWords")
        print("🔓 All chapters unlocked for testing.")
    }

    // MARK: - Full Reset
    func resetAllProgress() {
        let d = defaults

        d.removeObject(forKey: "learnedWords")
        d.removeObject(forKey: "currentStreak")
        d.removeObject(forKey: "bestStreak")
        d.removeObject(forKey: "lastActiveDate")
        d.removeObject(forKey: learningActivityKey)
        d.removeObject(forKey: memoryKey)

        for chapter in ChapterList.allCases {
            d.removeObject(forKey: reviewKeyPrefix + chapter.rawValue)
            d.removeObject(forKey: "mastery_" + chapter.rawValue)
        }

        d.removeObject(forKey: "averageRecallAccuracy")
        XPManager.shared.resetXP()
        HeartsManager.shared.reset()
        d.synchronize()

        print("🔁 ALL progress reset.")

        resetWeeklyActivity()
    }

    // MARK: - Cache Refresh
    func refreshAllProgressCache() {
        for chapter in ChapterList.allCases {
            _ = progress(for: chapter)
        }
    }

    /// Returns the last 7 days of activity as (date, count) tuples.
    /// Used by ProgressDashboardView's bar chart.
    func fetchWeeklyActivity() -> [(date: String, count: Int)] {
        weeklyActivity().map { (date: $0.date, count: $0.wordsLearned) }
    }

    func allChapterProgress() -> [ChapterList: Double] {
        var dict: [ChapterList: Double] = [:]
        for chapter in ChapterList.allCases {
            dict[chapter] = progress(for: chapter)
        }
        return dict
    }
    
    func deferCheckpoint(chapter: ChapterList, section: Int, until date: Date) {
        var checkpoints = reviewCheckpoints(for: chapter)

        if let idx = checkpoints.firstIndex(where: { $0.section == section }) {
            checkpoints[idx].scheduledDate = date
            checkpoints[idx].completed = false
            saveCheckpoints(checkpoints, for: chapter)
        }
    }
    
    func delayCheckpoint(_ checkpoint: ReviewCheckpoint, for chapter: ChapterList) {
        var cps = reviewCheckpoints(for: chapter)
        if let idx = cps.firstIndex(where: { $0.section == checkpoint.section }) {
            cps[idx].scheduledDate = Date().addingTimeInterval(15 * 60) // 15 minutes delay
            saveCheckpoints(cps, for: chapter)
        }
    }



}

// clamped(to:) is defined globally in ViewExtensions.swift via extension Comparable

// MARK: - Daily Activity Model
struct DailyActivity: Codable, Identifiable, Equatable {
    let id = UUID()
    let date: String      // format: "yyyy-MM-dd"
    var wordsLearned: Int
}
