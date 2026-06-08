//
//  SessionBuilder.swift
//  Patente-Learning
//
//  Builds the question queue for a daily "Today's Session" from the Core Set.
//
//  The core algorithm (`buildIDs`) is PURE — it depends only on Foundation and
//  plain inputs (id arrays + a chapter lookup), so it is deterministic and unit
//  testable in isolation. The app-facing convenience that pulls live state from
//  ExamProgressManager / BloccoStore lives in SessionBuilder+Store.swift.
//
//  Mix (self-balancing on concept coverage, not the calendar):
//      newFraction = clamp(1 − coverage, 0.2, 0.85)
//  Early (low coverage) → mostly NEW concepts (expand);
//  late (high coverage) → mostly REVIEW (lock in).
//  Cross-backfill keeps the session full whenever the combined pool allows;
//  results are interleaved (no new/review blocks) and spread across chapters.
//

import Foundation

enum SessionBuilder {

    /// Pure inputs for the queue algorithm.
    struct Inputs {
        var size: Int
        /// Concept coverage 0…1 — drives the new/review split.
        var coverage: Double
        /// Due/weak seen core questions, worst-confidence first.
        var reviewIDs: [String]
        /// Unseen core questions, in store (chapter/Blocco) order.
        var newIDs: [String]
        /// Maps a question id to its chapter (for stratify + run-break).
        var chapterOf: (String) -> String?
        /// Chapter display order (for deterministic stratification).
        var chapterOrder: [String]
        /// Max consecutive same-chapter questions allowed.
        var maxSameChapterRun: Int = 3
    }

    /// Build the ordered list of question ids for a session.
    static func buildIDs(_ input: Inputs) -> [String] {
        let size = max(0, input.size)
        guard size > 0 else { return [] }

        let newFraction = min(0.85, max(0.2, 1 - input.coverage))
        var newTarget = Int((Double(size) * newFraction).rounded())
        var reviewTarget = size - newTarget

        let newAvail = input.newIDs.count
        let reviewAvail = input.reviewIDs.count

        // Cross-backfill: if one pool is short, shift its deficit to the other
        // so the session stays full whenever newAvail + reviewAvail ≥ size.
        if newTarget > newAvail {
            reviewTarget += newTarget - newAvail
            newTarget = newAvail
        }
        if reviewTarget > reviewAvail {
            newTarget = min(newAvail, newTarget + (reviewTarget - reviewAvail))
            reviewTarget = reviewAvail
        }

        let reviewPick = Array(input.reviewIDs.prefix(reviewTarget))
        let newPick = stratified(input.newIDs,
                                 count: newTarget,
                                 chapterOf: input.chapterOf,
                                 order: input.chapterOrder)

        let merged = interleave(newPick, reviewPick)
        return breakChapterRuns(merged,
                                chapterOf: input.chapterOf,
                                maxRun: input.maxSameChapterRun)
    }

    // MARK: - Building blocks (internal for testability)

    /// Pick `count` ids spread evenly across chapters (round-robin), preserving
    /// within-chapter order. Returns all ids (in order) when count ≥ available.
    static func stratified(_ ids: [String],
                           count: Int,
                           chapterOf: (String) -> String?,
                           order: [String]) -> [String] {
        guard count > 0 else { return [] }
        guard count < ids.count else { return ids }

        var byChapter: [String: [String]] = [:]
        var firstSeen: [String] = []
        for id in ids {
            let ch = chapterOf(id) ?? ""
            if byChapter[ch] == nil { firstSeen.append(ch) }
            byChapter[ch, default: []].append(id)
        }
        let chapters = order.filter { byChapter[$0] != nil }
            + firstSeen.filter { !order.contains($0) }

        var result: [String] = []
        var cursor: [String: Int] = [:]
        var advanced = true
        while result.count < count && advanced {
            advanced = false
            for ch in chapters {
                if result.count >= count { break }
                let bucket = byChapter[ch]!
                let i = cursor[ch, default: 0]
                if i < bucket.count {
                    result.append(bucket[i])
                    cursor[ch] = i + 1
                    advanced = true
                }
            }
        }
        return result
    }

    /// Alternate the two lists so neither forms a contiguous block.
    static func interleave(_ a: [String], _ b: [String]) -> [String] {
        var result: [String] = []
        result.reserveCapacity(a.count + b.count)
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count { result.append(a[i]); i += 1 }
            if j < b.count { result.append(b[j]); j += 1 }
        }
        return result
    }

    /// Best-effort: break runs longer than `maxRun` of the same chapter by
    /// swapping in a later question from a different chapter.
    static func breakChapterRuns(_ ids: [String],
                                 chapterOf: (String) -> String?,
                                 maxRun: Int) -> [String] {
        guard maxRun > 0, ids.count > maxRun else { return ids }
        var res = ids
        var run = 1
        var i = 1
        while i < res.count {
            if chapterOf(res[i]) == chapterOf(res[i - 1]) {
                run += 1
            } else {
                run = 1
            }
            if run > maxRun,
               let j = ((i + 1)..<res.count).first(where: { chapterOf(res[$0]) != chapterOf(res[i]) }) {
                res.swapAt(i, j)
                run = 1
            }
            i += 1
        }
        return res
    }
}
