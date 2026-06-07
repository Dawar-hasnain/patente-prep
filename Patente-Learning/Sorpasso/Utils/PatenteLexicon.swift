//
//  PatenteLexicon.swift
//  Patente-Learning
//
//  Loads the curated patente glossary (Data/patente_glossary.json) — the
//  domain-correct IT->EN terms (e.g. "precedenza" -> "right of way").
//  Used for the ConceptCard "key terms" chips and as a high-priority gloss
//  source for tappable sentences.
//

import Foundation

final class PatenteLexicon {

    static let shared = PatenteLexicon()

    /// lowercase italian term -> english gloss
    private(set) var terms: [String: String] = [:]
    /// italian terms sorted longest-first (so multi-word phrases match before single words)
    private(set) var termsByLengthDesc: [String] = []

    private init() {
        guard let url = Bundle.main.url(forResource: "patente_glossary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            assertionFailure("patente_glossary.json missing or malformed")
            return
        }

        var table: [String: String] = [:]
        for (category, value) in root {
            if category.hasPrefix("_") { continue }            // skip _meta
            guard let entries = value as? [String: Any] else { continue }
            for (term, payload) in entries {
                if let dict = payload as? [String: Any],
                   let en = dict["en"] as? String {
                    table[term.lowercased()] = en
                }
            }
        }
        terms = table
        termsByLengthDesc = table.keys.sorted { $0.count > $1.count }
    }

    /// Direct gloss for a single term (punctuation-trimmed, lowercased).
    func gloss(for raw: String) -> String? {
        let clean = raw.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'()[]–—-«»"))
        guard !clean.isEmpty else { return nil }
        return terms[clean]
    }

    /// Glossary terms (italian) that appear in the given text, longest-match
    /// first, de-duplicated. Used to surface "key terms" for a Blocco.
    func keyTerms(in text: String, limit: Int = 8) -> [(it: String, en: String)] {
        let lower = text.lowercased()
        var found: [(String, String)] = []
        var seen = Set<String>()
        for term in termsByLengthDesc {
            guard !seen.contains(term) else { continue }
            // word-ish boundary check
            if lower.range(of: term) != nil, let en = terms[term] {
                found.append((term, en))
                seen.insert(term)
            }
            if found.count >= limit { break }
        }
        return found
    }
}
