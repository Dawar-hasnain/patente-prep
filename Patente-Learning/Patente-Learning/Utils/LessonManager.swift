//
//  LessonManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  Slices a chapter's word list into fixed-size lessons.
//  Uses the existing learnedWords store — no new persistence needed.
//

import Foundation

// MARK: - Lesson Model

struct Lesson: Identifiable {
    let id: Int                  // 0-based index within the chapter
    let chapterIndex: Int        // which chapter this belongs to (for display)
    let words: [Words]
    let isUnlocked: Bool
    let isComplete: Bool

    var displayNumber: Int { id + 1 }
    var totalWords: Int { words.count }
}

// MARK: - LessonManager

struct LessonManager {

    static let lessonSize = 8

    // MARK: - Build lessons for a chapter

    /// Returns all lessons for a chapter, with unlock and completion state baked in.
    static func lessons(for chapter: ChapterList) -> [Lesson] {
        let allWords = loadChapter(chapter.filename).words
        let learned  = Set(UserDefaults.standard.stringArray(forKey: "learnedWords") ?? [])

        // Slice words into chunks of lessonSize
        let slices = stride(from: 0, to: allWords.count, by: lessonSize).map { start -> [Words] in
            let end = min(start + lessonSize, allWords.count)
            return Array(allWords[start..<end])
        }

        var result: [Lesson] = []

        for (index, slice) in slices.enumerated() {
            let isComplete  = slice.allSatisfy { learned.contains($0.italian) }
            let isUnlocked  = index == 0 || result[index - 1].isComplete

            result.append(Lesson(
                id: index,
                chapterIndex: ChapterList.allCases.firstIndex(of: chapter) ?? 0,
                words: slice,
                isUnlocked: isUnlocked,
                isComplete: isComplete
            ))
        }

        return result
    }

    // MARK: - Convenience helpers

    /// How many lessons are fully complete for a chapter.
    static func completedLessonCount(for chapter: ChapterList) -> Int {
        lessons(for: chapter).filter { $0.isComplete }.count
    }

    /// Total lesson count for a chapter.
    static func totalLessonCount(for chapter: ChapterList) -> Int {
        lessons(for: chapter).count
    }

    /// The next incomplete, unlocked lesson — i.e. where the user should continue.
    static func nextLesson(for chapter: ChapterList) -> Lesson? {
        lessons(for: chapter).first { $0.isUnlocked && !$0.isComplete }
    }

    /// 0.0–1.0 chapter progress based on completed lessons (mirrors ProgressManager.progress).
    static func chapterProgress(for chapter: ChapterList) -> Double {
        let all = lessons(for: chapter)
        guard !all.isEmpty else { return 0 }
        return Double(all.filter { $0.isComplete }.count) / Double(all.count)
    }
}
