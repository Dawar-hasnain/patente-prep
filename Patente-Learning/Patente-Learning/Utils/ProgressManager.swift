//
//  ProgressManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

//
//  ProgressManager.swift
//  Patente-Learning
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

// MARK: – Progress Manager Extension
final class ProgressManager {
    // MARK: - Configurable Retry Interval
    #if DEBUG
    /// Fast retry for development (e.g. 1 minute)
    private let reviewRetryInterval: TimeInterval = 60
    #else
    /// Normal retry interval for production (24 hours)
    private let reviewRetryInterval: TimeInterval = 24 * 60 * 60
    #endif
    
    static let shared = ProgressManager()
    private let defaults = UserDefaults.standard
    private let reviewKeyPrefix = "reviewCheckpoints_"
    private let memoryKey = "wordMemoryStates"

    private init() {}

    // MARK: Retrieve / Initialize checkpoints
    func reviewCheckpoints(for chapter: ChapterList) -> [ReviewCheckpoint] {
        let key = reviewKeyPrefix + chapter.rawValue
        if let data = defaults.data(forKey: key),
           let checkpoints = try? JSONDecoder().decode([ReviewCheckpoint].self, from: data) {
            return checkpoints
        } else {
            // initialize 10 blank checkpoints
            let blank = (1...10).map { ReviewCheckpoint(section: $0,
                                                        completed: false,
                                                        scheduledDate: nil,
                                                        lastScore: nil) }
            saveCheckpoints(blank, for: chapter)
            return blank
        }
    }

    // MARK: Save checkpoints
    func saveCheckpoints(_ checkpoints: [ReviewCheckpoint], for chapter: ChapterList) {
        let key = reviewKeyPrefix + chapter.rawValue
        if let data = try? JSONEncoder().encode(checkpoints) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: Update one checkpoint
    func updateCheckpoint(for chapter: ChapterList,
                          section: Int,
                          passed: Bool,
                          score: Double) {
        var checkpoints = reviewCheckpoints(for: chapter)
        guard let index = checkpoints.firstIndex(where: { $0.section == section }) else { return }

        if passed {
            checkpoints[index].completed = true
            checkpoints[index].scheduledDate = nil
        } else {
            checkpoints[index].completed = false

            // 1️⃣ Schedule retry later (not immediate)
            checkpoints[index].scheduledDate = Date().addingTimeInterval(reviewRetryInterval)

            // 2️⃣ Mark it as “pending after more progress”
            checkpoints[index].lastScore = score

            // 3️⃣ 🔔 Schedule local notification for retry
            let retryDelay = max(0, reviewRetryInterval)
            NotificationManager.shared.scheduleNotification(
                title: "Review Ready",
                body: "Your retry for \(chapter.title) is now available!",
                after: retryDelay
            )

            print("📅 Retry for \(chapter.title) scheduled in \(retryDelay) seconds.")
        }

        checkpoints[index].lastScore = score
        saveCheckpoints(checkpoints, for: chapter)
    }


    // MARK: Find next pending checkpoint
    // MARK: - Pending Review Detection
    func nextPendingCheckpoint(for chapter: ChapterList) -> ReviewCheckpoint? {
        let checkpoints = reviewCheckpoints(for: chapter)
        let now = Date()

        // Skip chapters with no learning progress at all
        let progress = progress(for: chapter)
        guard progress > 0 else { return nil }

        // 🧩 Find first checkpoint that is incomplete AND due
        for checkpoint in checkpoints {
            let isIncomplete = checkpoint.completed == false
            let isDue = (checkpoint.scheduledDate == nil) || (checkpoint.scheduledDate! <= now)

            if isIncomplete && isDue {
                return checkpoint
            }
        }

        return nil
    }



    // MARK: Adaptive pass thresholds
    func passingThreshold(for progress: Double) -> Double {
        switch progress {
        case 0.0..<0.3: return 0.6
        case 0.3..<0.7: return 0.75
        case 0.7..<0.9: return 0.85
        default:        return 0.9
        }
    }

    // MARK: Utility for current section index (0-9)
    func currentSection(for progress: Double) -> Int {
        return Int(progress * 10.0)       // 0-9
    }

    // MARK: Reset all review progress
    func resetReviews() {
        for chapter in ChapterList.allCases {
            defaults.removeObject(forKey: reviewKeyPrefix + chapter.rawValue)
        }
        print("🧹 All review checkpoints cleared.")
    }
    
    // MARK: - Chapter Progress Percentage
    func progress(for chapter: ChapterList) -> Double {
        // Check how many words have been marked as learned for this chapter
        guard let learnedWords = UserDefaults.standard.array(forKey: "learnedWords") as? [String] else {
            return 0.0
        }
        let total = loadChapter(chapter.filename).words.count
        guard total > 0 else { return 0.0 }

        // Count how many words from this chapter are in the learnedWords list
        let learnedCount = loadChapter(chapter.filename).words.filter { learnedWords.contains($0.italian) }.count
        return Double(learnedCount) / Double(total)
    }

    // MARK: - Log Daily Learning Activity
    func logDailyLearningActivity() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        
        var log = (UserDefaults.standard.dictionary(forKey: "learningActivity") as? [String: Int]) ?? [:]
        log[todayKey, default: 0] += 1
        UserDefaults.standard.setValue(log, forKey: "learningActivity")
    }
    
    // MARK: - Weekly Activity Tracking (Unified)
    private let learningActivityKey = "learningActivity"

    /// Retrieve the last 7 days of learning activity
    func weeklyActivity() -> [DailyActivity] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        var result: [DailyActivity] = []
        let log = (UserDefaults.standard.dictionary(forKey: learningActivityKey) as? [String: Int]) ?? [:]
        
        for i in (0..<7).reversed() {
            if let date = Calendar.current.date(byAdding: .day, value: -i, to: today) {
                let key = formatter.string(from: date)
                let count = log[key] ?? 0
                result.append(DailyActivity(date: key, wordsLearned: count))
            }
        }
        return result
    }

    /// Reset the weekly/daily activity data
    func resetWeeklyActivity() {
        UserDefaults.standard.removeObject(forKey: learningActivityKey)
    }

    func loadMemoryStates() -> [WordMemoryState] {
        if let data = UserDefaults.standard.data(forKey: memoryKey),
           let decoded = try? JSONDecoder().decode([WordMemoryState].self, from: data) {
            return decoded
        }
        return []
    }

    func saveMemoryStates(_ states: [WordMemoryState]) {
        if let encoded = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(encoded, forKey: memoryKey)
        }
    }

    func updateMemoryState(for word: String, correct: Bool) {
        var states = loadMemoryStates()
        if let index = states.firstIndex(where: { $0.word == word }) {
            states[index].updatePerformance(correct: correct)
        } else {
            var new = WordMemoryState(word: word, lastReviewed: Date(), confidence: correct ? 0.5 : 0.3, correctCount: 0, incorrectCount: 0)
            new.updatePerformance(correct: correct)
            states.append(new)
        }
        saveMemoryStates(states)
    }
    
    // MARK: - Adaptive Scheduling Engine
    func nextReviewDate(for word: String) -> Date {
        let states = loadMemoryStates()
        guard let state = states.first(where: { $0.word == word }) else {
            return Date().addingTimeInterval(60 * 60 * 6) // 6h fallback
        }
        
        let baseInterval: TimeInterval
        switch state.confidence {
        case 0.0..<0.3: baseInterval = 6 * 3600        // 6 hours
        case 0.3..<0.6: baseInterval = 12 * 3600       // 12 hours
        case 0.6..<0.8: baseInterval = 24 * 3600       // 1 day
        default:        baseInterval = 48 * 3600       // 2 days
        }
        
        // Slight randomness to avoid mechanical recall
        let jitter = Double.random(in: -0.1...0.1) * baseInterval
        return state.lastReviewed.addingTimeInterval(baseInterval + jitter)
    }
    
    func weakWords(threshold: Double = 0.5, limit: Int = 10) -> [WordMemoryState] {
        var states = loadMemoryStates()
        // Apply memory decay before filtering weak words
        for i in 0..<states.count {
            states[i].applyDecay() // Apply the decay to memory
        }
        saveMemoryStates(states)

        return states
            .filter { $0.confidence < threshold }
            .sorted(by: { $0.confidence < $1.confidence })
            .prefix(limit)
            .map { $0 } // return the full `WordMemoryState` object, not just the word
    }


    // 🔍 Return weakest words for recall practice
    func weakMemoryWords(threshold: Double = 0.5, limit: Int = 10) -> [WordMemoryState] {
        var states = loadMemoryStates()
        for i in 0..<states.count { states[i].applyDecay() } // apply forgetting
        saveMemoryStates(states)
        return states
            .filter { $0.confidence < threshold }
            .sorted(by: { $0.confidence < $1.confidence })
            .prefix(limit)
            .map { $0 }
    }

    // 📊 Helper for translation lookup
    func translation(for word: String) -> String? {
        for chapter in ChapterList.allCases {
            let words = loadChapter(chapter.filename).words
            if let entry = words.first(where: { $0.italian == word }) {
                return entry.english
            }
        }
        return nil
    }


}

// MARK: - Chapter Mastery Tracking

struct ChapterMastery: Codable {
    let chapter: ChapterList
    var isMastered: Bool
    var lastReviewed: Date?
    var score: Double?
}

// MARK: - Daily Activity Model
struct DailyActivity: Codable, Identifiable {
    let id = UUID()
    let date: String   // format: "yyyy-MM-dd"
    var wordsLearned: Int
}

extension ProgressManager {
    func markChapterAsMastered(_ chapter: ChapterList, score: Double) {
        let key = "mastery_" + chapter.rawValue
        let record = ChapterMastery(chapter: chapter,
                                    isMastered: true,
                                    lastReviewed: Date(),
                                    score: score)
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func isChapterMastered(_ chapter: ChapterList) -> Bool {
        let key = "mastery_" + chapter.rawValue
        guard let data = UserDefaults.standard.data(forKey: key),
              let record = try? JSONDecoder().decode(ChapterMastery.self, from: data)
        else { return false }
        return record.isMastered
    }
    
    func hasAttemptedFinalReview(_ chapter: ChapterList) -> Bool {
        let key = "mastery_" + chapter.rawValue
        guard let data = UserDefaults.standard.data(forKey: key),
              let record = try? JSONDecoder().decode(ChapterMastery.self, from: data)
        else { return false }
        return record.score != nil
    }

}

// MARK: - Progress & Analytics Extensions
extension ProgressManager {

    /// Total words learned across all chapters
    func totalLearnedWords() -> Int {
        let learned = UserDefaults.standard.stringArray(forKey: "learnedWords") ?? []
        return learned.count
    }

    /// Total chapters that are fully mastered (passed final review)
    func totalChaptersMastered() -> Int {
        ChapterList.allCases.filter { isChapterMastered($0) }.count
    }

    /// Average score across all mastered or reviewed chapters
    func averageScore() -> Double {
        let allScores = ChapterList.allCases.compactMap { chapter -> Double? in
            guard let data = UserDefaults.standard.data(forKey: "mastery_" + chapter.rawValue),
                  let record = try? JSONDecoder().decode(ChapterMastery.self, from: data),
                  let score = record.score else { return nil }
            return score
        }

        guard !allScores.isEmpty else { return 0.0 }
        return allScores.reduce(0, +) / Double(allScores.count)
    }

    /// Last date of user activity (learning or review)
    func lastActiveDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lastActiveDate") as? Date
    }

    /// Save last activity date (call on any learning event)
    func updateLastActiveDate() {
        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
    }
    
    func nextPendingReview() -> (chapter: ChapterList, checkpoint: ReviewCheckpoint)? {
            for chapter in ChapterList.allCases {
                if let pending = nextPendingCheckpoint(for: chapter) {
                    return (chapter, pending)
                }
            }
            return nil
        }
    
    /// Instantly marks all chapters as mastered for testing
        func unlockAllChaptersForTesting() {
            // 1️⃣ Mark every word as learned
            var allWords: [String] = []
            for chapter in ChapterList.allCases {
                let words = loadChapter(chapter.filename).words.map { $0.italian }
                allWords.append(contentsOf: words)

                // 2️⃣ Mark chapter as mastered
                let mastery = ChapterMastery(
                    chapter: chapter,
                    isMastered: true,
                    lastReviewed: Date(),
                    score: 1.0
                )

                if let data = try? JSONEncoder().encode(mastery) {
                    UserDefaults.standard.set(data, forKey: "mastery_" + chapter.rawValue)
                }

                // 3️⃣ Initialize all review checkpoints as completed
                let checkpoints = (1...10).map {
                    ReviewCheckpoint(section: $0, completed: true, scheduledDate: nil, lastScore: 1.0)
                }
                saveCheckpoints(checkpoints, for: chapter)
            }

            // 4️⃣ Save all words globally
            UserDefaults.standard.set(allWords, forKey: "learnedWords")

            print("✅ All chapters unlocked for testing.")
        }

        /// Fetches last 7 days of learning data
        func fetchWeeklyActivity() -> [(date: String, count: Int)] {
            let activity = UserDefaults.standard.dictionary(forKey: "learningActivity") as? [String: Int] ?? [:]
            let calendar = Calendar.current
            let today = Date()

            var result: [(String, Int)] = []
            for i in (0..<7).reversed() {
                let date = calendar.date(byAdding: .day, value: -i, to: today)!
                let key = formattedDateKey(for: date)
                result.append((key, activity[key] ?? 0))
            }
            return result
        }

        private func formattedDateKey(for date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    
    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        var bestStreak = UserDefaults.standard.integer(forKey: "bestStreak")
        let lastActive = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date

        if let last = lastActive {
            let lastDay = calendar.startOfDay(for: last)
            let components = calendar.dateComponents([.day], from: lastDay, to: today)

            if components.day == 0 {
                // same day — do nothing
                return
            } else if components.day == 1 {
                // consecutive day — increment streak
                currentStreak += 1
            } else {
                // missed a day — reset streak and notify user
                currentStreak = 1

                // 🔔 Schedule gentle motivation reminder
                NotificationManager.shared.scheduleNotification(
                    title: "Don't lose your momentum!",
                    body: "You missed your learning streak yesterday — let’s get back on track 💪",
                    after: 5 // use 3600 (1 hour) for production
                )
            }
        } else {
            // first ever day
            currentStreak = 1
        }

        // Save updated streaks
        bestStreak = max(bestStreak, currentStreak)
        UserDefaults.standard.set(currentStreak, forKey: "currentStreak")
        UserDefaults.standard.set(bestStreak, forKey: "bestStreak")
        UserDefaults.standard.set(today, forKey: "lastActiveDate")
    }


        func currentStreak() -> Int {
            UserDefaults.standard.integer(forKey: "currentStreak")
        }

        func bestStreak() -> Int {
            UserDefaults.standard.integer(forKey: "bestStreak")
        }
    
    func averageRecallAccuracy() -> Double {
        // Placeholder until we store recall scores — returning 0.85 (85%) for now
        return UserDefaults.standard.double(forKey: "averageRecallAccuracy").clamped(to: 0...1)
    }
    
    // MARK: - Reset All Progress
    func resetAllProgress() {
        let defaults = UserDefaults.standard

        // 🧹 Clear learned words
        defaults.removeObject(forKey: "learnedWords")

        // 🧹 Clear streak data
        defaults.removeObject(forKey: "currentStreak")
        defaults.removeObject(forKey: "bestStreak")
        defaults.removeObject(forKey: "lastActiveDate")
        
        // 🧹 Clear daily/weekly activity logs
        defaults.removeObject(forKey: "dailyLearningLog")
        defaults.removeObject(forKey: "weeklyActivityData")

        // 🧹 Clear review checkpoints
        for chapter in ChapterList.allCases {
            let key = reviewKeyPrefix + chapter.rawValue
            defaults.removeObject(forKey: key)
        }
        
        // 🧹 Clear chapter unlock and completion states
        for chapter in ChapterList.allCases {
            let unlockKey = "chapterUnlocked_\(chapter.rawValue)"
            let completeKey = "chapterCompleted_\(chapter.rawValue)"
            defaults.removeObject(forKey: unlockKey)
            defaults.removeObject(forKey: completeKey)
        }

        // 🧹 Clear accuracy stats (if present)
        defaults.removeObject(forKey: "averageRecallAccuracy")

        defaults.synchronize()
        print("🔁 All progress data fully reset.")
        
        resetWeeklyActivity()
    }
    
    // MARK: - Refresh cached progress
    func refreshAllProgressCache() {
        for chapter in ChapterList.allCases {
            // force recomputation (in case progress values are cached internally)
            _ = progress(for: chapter)
        }
    }
    
    // MARK: - Compute All Chapter Progress
    func allChapterProgress() -> [ChapterList: Double] {
        var dict: [ChapterList: Double] = [:]
        for chapter in ChapterList.allCases {
            dict[chapter] = progress(for: chapter)
        }
        return dict
    }
}
