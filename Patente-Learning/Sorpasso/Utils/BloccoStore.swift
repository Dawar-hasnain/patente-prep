//
//  BloccoStore.swift
//  Patente-Learning
//
//  Loads the official exam bank (Data/questions_v2_en.json) once and exposes
//  it indexed by chapter and by Blocco id. Replaces the per-chapter
//  loadChapter()/JSONLoader vocab loading for the new exam-prep flow.
//

import Foundation

final class BloccoStore {

    static let shared = BloccoStore()

    /// All Blocchi in file order.
    let blocchi: [Blocco]
    /// Chapter name (e.g. "LA STRADA") -> its Blocchi, preserving order.
    let blocchiByChapter: [String: [Blocco]]
    /// Chapter names in first-seen order.
    let chapterOrder: [String]

    private let byId: [String: Blocco]
    private lazy var questionsById: [String: Question] = {
        var map: [String: Question] = [:]
        for q in allQuestions { map[q.id] = q }
        return map
    }()

    private init() {
        guard let url = Bundle.main.url(forResource: "questions_v2_en", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("questions_v2_en.json missing from bundle")
            self.blocchi = []
            self.blocchiByChapter = [:]
            self.chapterOrder = []
            self.byId = [:]
            return
        }

        do {
            let bank = try JSONDecoder().decode(QuestionBank.self, from: data)
            self.blocchi = bank.blocchi
        } catch {
            assertionFailure("Failed to decode question bank: \(error)")
            self.blocchi = []
        }

        // Build indexes.
        var grouped: [String: [Blocco]] = [:]
        var order: [String] = []
        var ids: [String: Blocco] = [:]
        for b in blocchi {
            if grouped[b.chapter] == nil { order.append(b.chapter) }
            grouped[b.chapter, default: []].append(b)
            ids[b.blocco_id] = b
        }
        self.blocchiByChapter = grouped
        self.chapterOrder = order
        self.byId = ids
    }

    // MARK: - Lookups

    func blocco(id: String) -> Blocco? { byId[id] }

    func question(id: String) -> Question? { questionsById[id] }

    func questions(ids: [String]) -> [Question] { ids.compactMap { questionsById[$0] } }

    func blocchi(in chapter: String) -> [Blocco] { blocchiByChapter[chapter] ?? [] }

    /// Every question across all Blocchi — used by the mock exam sampler.
    var allQuestions: [Question] { blocchi.flatMap(\.questions) }

    var totalQuestionCount: Int { allQuestions.count }

    // MARK: - Core Set (concept-representative study pool)

    /// The number of distinct concepts (Blocchi) — the unit readiness is
    /// measured against. The bank's 7142 questions are ~10 paraphrased variants
    /// per concept; mastering the concept transfers to its variants, so the
    /// real "things to learn" count is this, not the raw question total.
    var conceptCount: Int { blocchi.count }

    /// Up to 2 representative questions per Blocco — one VERO and one FALSO when
    /// both exist — so each concept is practised in both polarities. This is the
    /// pool the daily session and concept-level readiness draw from.
    /// Deterministic (sorted by id) so it's stable across launches.
    lazy var coreQuestionsByBlocco: [String: [Question]] = {
        var map: [String: [Question]] = [:]
        for b in blocchi {
            let sorted = b.questions.sorted { $0.id < $1.id }
            var picks: [Question] = []
            if let v = sorted.first(where: { $0.answer == true })  { picks.append(v) }
            if let f = sorted.first(where: { $0.answer == false }) { picks.append(f) }
            if picks.isEmpty, let first = sorted.first { picks.append(first) }
            map[b.blocco_id] = picks
        }
        return map
    }()

    /// Flat core-question pool in chapter/Blocco order.
    lazy var coreQuestions: [Question] = {
        blocchi.flatMap { coreQuestionsByBlocco[$0.blocco_id] ?? [] }
    }()

    /// Fraction of concepts (Blocchi) belonging to each chapter — used to
    /// stratify "new concept" sampling so a session isn't all one chapter.
    lazy var chapterWeights: [String: Double] = {
        guard !blocchi.isEmpty else { return [:] }
        var counts: [String: Int] = [:]
        for b in blocchi { counts[b.chapter, default: 0] += 1 }
        let total = Double(blocchi.count)
        return counts.mapValues { Double($0) / total }
    }()

    /// Core question id → its Blocco's chapter (for session stratification).
    lazy var coreQuestionChapter: [String: String] = {
        var map: [String: String] = [:]
        for b in blocchi {
            for q in coreQuestionsByBlocco[b.blocco_id] ?? [] {
                map[q.id] = b.chapter
            }
        }
        return map
    }()
}
