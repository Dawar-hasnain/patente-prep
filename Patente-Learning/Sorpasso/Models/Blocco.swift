//
//  Blocco.swift
//  Patente-Learning
//
//  New exam-bank data model (replaces the vocab-centric Words/Chapter model).
//
//  Maps directly to Data/questions_v2_en.json — the official ministry
//  question bank: 716 Blocchi (concept clusters), 7142 true/false questions,
//  each with Italian source text and an English machine-translation.
//
//  Stable string IDs come straight from the JSON ("11013-V-1"), so there is
//  NO `let id = UUID()` decode trap here — decoding reads `id` from the file.
//

import Foundation

/// One official true/false exam question.
struct Question: Identifiable, Codable, Hashable {
    let id: String          // e.g. "11013-V-1"
    let text: String        // Italian (exam language)
    let text_en: String     // English gloss (machine-translated + glossary-corrected)
    let answer: Bool        // ground truth: true = VERO, false = FALSO
}

/// One Blocco — a ministry concept cluster grouping related questions
/// under a single topic. This is the unit the learner studies & practises.
struct Blocco: Identifiable, Codable {
    var id: String { blocco_id }

    let blocco_id: String           // 5-digit hierarchical id, e.g. "11013"
    let topic: String               // Italian topic label
    let topic_en: String            // English topic label
    let chapter: String             // macro chapter, e.g. "LA STRADA"
    let sub_section: String?
    let question_count_true: Int
    let question_count_false: Int
    let questions: [Question]
    let figures: [String]           // figure numbers, e.g. ["550"]

    // Concept summary (L3 teaching layer) — added later; optional so the
    // current JSON (which has no summary) still decodes cleanly.
    let concept_summary_en: String?

    /// Bundle image names for this Blocco's figures, e.g. "fig_0550".
    var figureImageNames: [String] {
        figures.map { num in
            let padded = String(repeating: "0", count: max(0, 4 - num.count)) + num
            return "fig_\(padded)"
        }
    }
}

/// Top-level container matching the JSON root object.
struct QuestionBank: Codable {
    let source: String
    let blocchi_count: Int
    let question_count: Int
    let blocchi: [Blocco]
}
