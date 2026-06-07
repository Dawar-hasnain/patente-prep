//
//  ExamProgressManager.swift
//  Patente-Learning
//
//  Fresh progress tracking for the exam-bank flow — keyed on REAL question IDs
//  and Blocco IDs (e.g. "11013-V-1", "11013"), independent of the legacy
//  word-string progress in ProgressManager. Nothing here migrates the old data;
//  it starts clean.
//
//  Persistence: a single JSON blob in UserDefaults ("examQuestionProgress").
//

import Foundation
import Combine

/// Per-question memory state, keyed by the question's stable string id.
struct QuestionProgress: Codable {
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var confidence: Double = 0.0     // 0…1, EMA-style mastery signal
    var lastSeen: Date = Date()

    var attempts: Int { correctCount + incorrectCount }
    var accuracy: Double { attempts > 0 ? Double(correctCount) / Double(attempts) : 0 }

    mutating func record(correct: Bool) {
        lastSeen = Date()
        if correct {
            correctCount += 1
            confidence = min(1.0, confidence + 0.15)
        } else {
            incorrectCount += 1
            confidence = max(0.0, confidence - 0.20)
        }
    }

    /// Confidence erodes slowly with time so stale mastery doesn't overstate readiness.
    func decayedConfidence(asOf now: Date = Date()) -> Double {
        let hours = max(0, now.timeIntervalSince(lastSeen)) / 3600
        let decay = hours / 400.0          // ~full decay over ~16 days idle
        return max(0.0, confidence - decay)
    }
}

final class ExamProgressManager: ObservableObject {

    static let shared = ExamProgressManager()

    private let defaults = UserDefaults.standard
    private let storageKey = "examQuestionProgress"

    /// questionID -> progress
    @Published private(set) var states: [String: QuestionProgress]

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: QuestionProgress].self, from: data) {
            states = decoded
        } else {
            states = [:]
        }
    }

    // MARK: - Recording

    /// Record a single answered question. `correct` is whether the user's
    /// VERO/FALSO choice matched the ground truth.
    func record(questionID: String, correct: Bool) {
        var s = states[questionID] ?? QuestionProgress()
        s.record(correct: correct)
        states[questionID] = s
        persist()
    }

    func record(_ question: Question, correct: Bool) {
        record(questionID: question.id, correct: correct)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Question-level lookups

    func progress(for questionID: String) -> QuestionProgress? { states[questionID] }

    var seenQuestionCount: Int { states.count }

    // MARK: - Blocco-level mastery

    /// Mastery of one Blocco: average decayed confidence across its questions
    /// (unseen questions count as 0). 0…1.
    func mastery(for blocco: Blocco) -> Double {
        guard !blocco.questions.isEmpty else { return 0 }
        let now = Date()
        let total = blocco.questions.reduce(0.0) { acc, q in
            acc + (states[q.id]?.decayedConfidence(asOf: now) ?? 0)
        }
        return total / Double(blocco.questions.count)
    }

    /// How many of a Blocco's questions have been attempted at least once.
    func attemptedCount(in blocco: Blocco) -> Int {
        blocco.questions.reduce(0) { $0 + ((states[$1.id]?.attempts ?? 0) > 0 ? 1 : 0) }
    }

    // MARK: - Corpus-wide signals (for ReadinessEngine)

    /// Fraction of the whole bank attempted at least once. 0…1.
    func coverage(of store: BloccoStore = .shared) -> Double {
        let total = store.totalQuestionCount
        guard total > 0 else { return 0 }
        let attempted = states.values.filter { $0.attempts > 0 }.count
        return min(1.0, Double(attempted) / Double(total))
    }

    /// Average decayed confidence over questions the user has actually seen. 0…1.
    /// Returns nil if nothing has been attempted yet.
    func averageSeenConfidence() -> Double? {
        let seen = states.values.filter { $0.attempts > 0 }
        guard !seen.isEmpty else { return nil }
        let now = Date()
        let total = seen.reduce(0.0) { $0 + $1.decayedConfidence(asOf: now) }
        return total / Double(seen.count)
    }

    /// Overall accuracy across every attempt recorded. 0…1 (nil if no attempts).
    func overallAccuracy() -> Double? {
        let totalCorrect = states.values.reduce(0) { $0 + $1.correctCount }
        let totalAttempts = states.values.reduce(0) { $0 + $1.attempts }
        guard totalAttempts > 0 else { return nil }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    // MARK: - Concept-level (Blocco) signals — used by ReadinessEngine & sessions

    /// Whether a concept has been seen: at least one of its core representative
    /// questions has been attempted.
    private func conceptSeen(_ blocco: Blocco, store: BloccoStore) -> Bool {
        (store.coreQuestionsByBlocco[blocco.blocco_id] ?? [])
            .contains { (states[$0.id]?.attempts ?? 0) > 0 }
    }

    /// Fraction of concepts (Blocchi) seen at least once. 0…1.
    func conceptCoverage(of store: BloccoStore = .shared) -> Double {
        let all = store.blocchi
        guard !all.isEmpty else { return 0 }
        let seen = all.reduce(0) { $0 + (conceptSeen($1, store: store) ? 1 : 0) }
        return Double(seen) / Double(all.count)
    }

    /// Number of concepts seen at least once.
    func seenConceptCount(of store: BloccoStore = .shared) -> Int {
        store.blocchi.reduce(0) { $0 + (conceptSeen($1, store: store) ? 1 : 0) }
    }

    /// Decayed-confidence mastery of one concept: average over its core
    /// representatives (unseen reps count as 0). 0…1.
    func conceptMastery(for blocco: Blocco, store: BloccoStore = .shared, asOf now: Date = Date()) -> Double {
        let reps = store.coreQuestionsByBlocco[blocco.blocco_id] ?? []
        guard !reps.isEmpty else { return 0 }
        let total = reps.reduce(0.0) { $0 + (states[$1.id]?.decayedConfidence(asOf: now) ?? 0) }
        return total / Double(reps.count)
    }

    /// Average concept mastery over concepts that have been seen (nil if none).
    func averageConceptMastery(of store: BloccoStore = .shared) -> Double? {
        let now = Date()
        let seen = store.blocchi.filter { conceptSeen($0, store: store) }
        guard !seen.isEmpty else { return nil }
        let total = seen.reduce(0.0) { $0 + conceptMastery(for: $1, store: store, asOf: now) }
        return total / Double(seen.count)
    }

    /// Number of concepts whose mastery is at or above `threshold`.
    func masteredConceptCount(of store: BloccoStore = .shared,
                              threshold: Double = 0.6,
                              asOf now: Date = Date()) -> Int {
        store.blocchi.reduce(0) {
            $0 + (conceptMastery(for: $1, store: store, asOf: now) >= threshold ? 1 : 0)
        }
    }

    // MARK: - Core-set pools (for the daily session builder)

    /// Core questions never attempted — for expanding concept coverage.
    func unseenCoreIDs(of store: BloccoStore = .shared) -> [String] {
        store.coreQuestions.compactMap { (states[$0.id]?.attempts ?? 0) > 0 ? nil : $0.id }
    }

    /// Seen core questions below a confidence threshold, worst-first — for review.
    func dueOrWeakCoreIDs(of store: BloccoStore = .shared,
                          threshold: Double = 0.6,
                          limit: Int = .max) -> [String] {
        let now = Date()
        return store.coreQuestions
            .filter { (states[$0.id]?.attempts ?? 0) > 0 }
            .map { ($0.id, states[$0.id]!.decayedConfidence(asOf: now)) }
            .filter { $0.1 < threshold }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    // MARK: - Weak questions

    /// Lowest-confidence seen questions, for targeted review.
    func weakQuestionIDs(limit: Int = 20) -> [String] {
        let now = Date()
        return states
            .filter { $0.value.attempts > 0 }
            .sorted { $0.value.decayedConfidence(asOf: now) < $1.value.decayedConfidence(asOf: now) }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Reset

    func resetAll() {
        states = [:]
        defaults.removeObject(forKey: storageKey)
    }
}
