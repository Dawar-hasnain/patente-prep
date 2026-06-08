//
//  SessionBuilder+Store.swift
//  Patente-Learning
//
//  App-facing bridge for SessionBuilder: pulls live state from
//  ExamProgressManager + BloccoStore and returns resolved Questions in the
//  built order. Kept separate from the pure algorithm so the latter stays
//  unit-testable without app dependencies.
//

import Foundation

extension SessionBuilder {

    /// Threshold below which a seen core question is considered due for review.
    static let reviewThreshold = 0.6

    /// Build a daily session of `size` questions from the live Core Set state.
    static func buildSession(size: Int,
                             progress: ExamProgressManager = .shared,
                             store: BloccoStore = .shared) -> [Question] {
        let input = Inputs(
            size: size,
            coverage: progress.conceptCoverage(of: store),
            reviewIDs: progress.dueOrWeakCoreIDs(of: store, threshold: reviewThreshold),
            newIDs: progress.unseenCoreIDs(of: store),
            chapterOf: { store.coreQuestionChapter[$0] },
            chapterOrder: store.chapterOrder
        )
        return store.questions(ids: buildIDs(input))
    }
}
