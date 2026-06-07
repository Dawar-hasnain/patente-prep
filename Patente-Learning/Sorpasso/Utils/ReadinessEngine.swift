//
//  ReadinessEngine.swift
//  Patente-Learning
//
//  Estimates the learner's probability of passing a real patente mock exam
//  (30 questions, fail on the 3rd mistake) from their per-question accuracy
//  and how much of the bank they've covered.
//
//  Model:
//    • For a randomly drawn exam question, the chance the learner answers it
//      correctly is a blend of:
//         – p_seen  : their measured mastery on questions they've practised
//         – p_prior : a baseline for unseen questions (a true/false guess,
//                     nudged up slightly because exam statements are written
//                     to be answerable with general knowledge)
//      weighted by coverage c (fraction of the bank attempted):
//         p = c · p_seen + (1 − c) · p_prior
//    • The exam is 30 i.i.d.-ish draws; passing needs ≤ 3 wrong.
//      P(pass) = Σ_{k=0..3} C(30,k) (1−p)^k p^(30−k)
//

import Foundation

struct ReadinessReport {
    let probabilityOfPassing: Double   // 0…1
    let perQuestionAccuracy: Double    // blended p used in the model
    let coverage: Double               // 0…1 fraction of bank attempted
    let seenConfidence: Double         // 0…1 mastery on practised questions
    let attemptedQuestions: Int
    let totalQuestions: Int

    /// A short human label for the score.
    var band: String {
        switch probabilityOfPassing {
        case 0.85...:    return "Exam ready"
        case 0.6..<0.85: return "Almost there"
        case 0.35..<0.6: return "Getting started"
        default:         return "Keep practising"
        }
    }
}

enum ReadinessEngine {

    // Exam parameters (mirror MockExamView).
    static let examQuestionCount = 30
    static let maxMistakes = 3

    /// Baseline correctness for an unseen true/false statement.
    /// 0.5 is a pure coin-flip; 0.65 reflects that many patente statements are
    /// answerable from general road sense, and that an unseen *variant* of a
    /// partly-covered concept isn't a blind guess.
    static let priorCorrectness = 0.65

    /// Readiness is measured at the CONCEPT level (Blocchi), not the raw 7142
    /// questions. The bank is ~10 paraphrased variants per concept; mastering a
    /// concept transfers to its variants. Measuring against ~716 concepts is
    /// both more truthful to how the exam reuses questions and what makes
    /// "exam-ready in weeks" achievable rather than a multi-year coverage slog.
    static func evaluate(
        progress: ExamProgressManager = .shared,
        store: BloccoStore = .shared
    ) -> ReadinessReport {
        let coverage = progress.conceptCoverage(of: store)        // concepts seen / total
        let pSeen = progress.averageConceptMastery(of: store) ?? 0 // mastery on seen concepts
        let attempted = progress.seenConceptCount(of: store)

        // Blend seen mastery with the prior for the unseen remainder.
        let p = coverage * pSeen + (1 - coverage) * priorCorrectness
        let pPass = probabilityOfAtMostKWrong(
            n: examQuestionCount,
            maxWrong: maxMistakes,
            pCorrect: p
        )

        return ReadinessReport(
            probabilityOfPassing: pPass,
            perQuestionAccuracy: p,
            coverage: coverage,
            seenConfidence: pSeen,
            attemptedQuestions: attempted,      // concepts seen
            totalQuestions: store.conceptCount  // total concepts (Blocchi)
        )
    }

    /// P(at most `maxWrong` failures in `n` Bernoulli trials), each trial a
    /// success with probability `pCorrect`.
    static func probabilityOfAtMostKWrong(n: Int, maxWrong: Int, pCorrect: Double) -> Double {
        let p = min(max(pCorrect, 0.0), 1.0)
        let q = 1 - p
        var total = 0.0
        for k in 0...maxWrong {
            // C(n,k) · q^k · p^(n−k)  — probability of exactly k wrong.
            total += binomial(n, k) * pow(q, Double(k)) * pow(p, Double(n - k))
        }
        return min(max(total, 0.0), 1.0)
    }

    /// Numerically stable binomial coefficient C(n, k).
    static func binomial(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return 0 }
        let kk = min(k, n - k)
        var result = 1.0
        for i in 0..<kk {
            result *= Double(n - i) / Double(i + 1)
        }
        return result
    }
}
