//
//  ChapterPathView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct ChapterPathView: View {
    @State private var progressDict: [ChapterList: Double] = [:]
    @State private var expandedChapter: ChapterList? = nil
    @State private var showPendingReview = false
    @State private var pendingReviewChapter: ChapterList? = nil
    @State private var pendingCheckpoint: ReviewCheckpoint? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                        // ── Up Next Hero Card ─────────────────────────────
                        UpNextCard(data: nextActionableLesson())
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // ── Review Banner ─────────────────────────────────
                        GeometryReader { geo in
                            if let pending = nextPendingReview() {
                                let offset = geo.frame(in: .global).minY
                                let fade = max(0, min(1, 1 - (offset / 500)))

                                Button(action: {
                                    pendingReviewChapter = pending.chapter
                                    pendingCheckpoint = pending.checkpoint
                                    showPendingReview = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Review Ready")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("Chapter: \(pending.chapter.title)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(14)
                                    .shadow(color: .orange.opacity(0.2), radius: 3, x: 0, y: 2)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    .opacity(fade)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(height: 70)
                        .zIndex(1)

                        // ── Chapter Path ──────────────────────────────────
                        VStack(spacing: 80) {
                            ForEach(Array(ChapterList.allCases.enumerated()), id: \.element) { index, chapter in
                                let progress   = progressDict[chapter] ?? 0
                                let isUnlocked = isChapterUnlocked(chapter)
                                let isExpanded = expandedChapter == chapter

                                VStack(spacing: 0) {

                                    // Chapter Node row
                                    HStack {
                                        if index.isMultiple(of: 2) {
                                            Spacer()
                                            chapterNode(
                                                chapter: chapter,
                                                progress: progress,
                                                isUnlocked: isUnlocked,
                                                isExpanded: isExpanded
                                            )
                                        } else {
                                            chapterNode(
                                                chapter: chapter,
                                                progress: progress,
                                                isUnlocked: isUnlocked,
                                                isExpanded: isExpanded
                                            )
                                            Spacer()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)

                                    // Lesson tray — expands below the tapped chapter node
                                    if isExpanded && isUnlocked {
                                        LessonTrayView(chapter: chapter) {
                                            // Collapse after launching a lesson
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                expandedChapter = nil
                                            }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                        .padding(.top, 16)
                                        .padding(.horizontal, 16)
                                    }

                                    // Connector line to next chapter
                                    if index < ChapterList.allCases.count - 1 {
                                        ConnectorWithProgress(
                                            progress: progress,
                                            isLeftAligned: index.isMultiple(of: 2)
                                        )
                                        .frame(width: 140, height: 80)
                                        .padding(.top, 10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 8)
                }
            }
        .onAppear(perform: updateAllProgress)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expandedChapter)
        // ── Pending Review Session ────────────────────────────────────────
        .fullScreenCover(isPresented: $showPendingReview, onDismiss: updateAllProgress) {
            if let chapter = pendingReviewChapter, let checkpoint = pendingCheckpoint {
                ReviewSessionView(
                    chapter: chapter,
                    currentProgress: ProgressManager.shared.progress(for: chapter),
                    checkpoint: checkpoint,
                    onCompletion: { passed, score in
                        ProgressManager.shared.updateCheckpoint(
                            for: chapter,
                            section: checkpoint.section,
                            passed: passed,
                            score: score
                        )
                        showPendingReview = false
                    },
                    onDismiss: {
                        ProgressManager.shared.delayCheckpoint(checkpoint, for: chapter)
                        showPendingReview = false
                    }
                )
            }
        }

    }

    // MARK: - Chapter Node Builder

    @ViewBuilder
    private func chapterNode(
        chapter: ChapterList,
        progress: Double,
        isUnlocked: Bool,
        isExpanded: Bool
    ) -> some View {
        let completed = LessonManager.completedLessonCount(for: chapter)
        let total     = LessonManager.totalLessonCount(for: chapter)

        Button {
            guard isUnlocked else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                expandedChapter = (expandedChapter == chapter) ? nil : chapter
            }
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .fill(
                        isUnlocked
                        ? LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(
                                isExpanded ? Color.yellow : (isUnlocked ? Color.blue : .gray.opacity(0.4)),
                                lineWidth: isExpanded ? 5 : 4
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                    .scaleEffect(isExpanded ? 1.06 : 1.0)

                // Icon + label
                VStack(spacing: 4) {
                    if ProgressManager.shared.isChapterMastered(chapter) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.yellow)
                    } else if isExpanded {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    } else if isUnlocked {
                        Image(systemName: "book.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }

                    Text(chapter.shortTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                // Lesson count badge (bottom-right)
                if isUnlocked && total > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(completed == total ? Color.green : Color.orange))
                        .offset(x: 28, y: 30)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }

    // MARK: - Helpers

    private func updateAllProgress() {
        withAnimation(.easeInOut(duration: 0.8)) {
            progressDict = ProgressManager.shared.allChapterProgress()
        }
    }

    private func isChapterUnlocked(_ chapter: ChapterList) -> Bool {
        let allChapters = ChapterList.allCases
        guard let index = allChapters.firstIndex(of: chapter) else { return false }
        if index == 0 { return true }
        let previous = allChapters[index - 1]
        return (progressDict[previous] ?? 0) >= 0.7
    }

    // MARK: - Review Banner Logic

    private func nextPendingReview() -> (chapter: ChapterList, checkpoint: ReviewCheckpoint)? {
        for chapter in ChapterList.allCases {
            if let pending = ProgressManager.shared.nextPendingCheckpoint(for: chapter) {
                return (chapter, pending)
            }
        }
        return nil
    }

    private func launchPendingReview(for chapter: ChapterList) {
        guard let pending = ProgressManager.shared.nextPendingCheckpoint(for: chapter) else { return }
        pendingReviewChapter = chapter
        pendingCheckpoint = pending
        showPendingReview = true
    }

    // MARK: - Reset / Unlock (Testing)

    private func resetProgress() {
        ProgressManager.shared.resetAllProgress()
        withAnimation(.spring()) {
            progressDict = [:]
            ProgressManager.shared.refreshAllProgressCache()
            updateAllProgress()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ProgressManager.shared.refreshAllProgressCache()
            updateAllProgress()
        }
    }

    func unlockAllChapters() {
        ProgressManager.shared.unlockAllChaptersForTesting()
        withAnimation(.spring()) { updateAllProgress() }
    }

    // MARK: - Up Next Logic

    /// Returns the first incomplete unlocked lesson across all chapters, in order.
    private func nextActionableLesson() -> (chapter: ChapterList, lesson: Lesson)? {
        for chapter in ChapterList.allCases {
            guard isChapterUnlocked(chapter) else { continue }
            if let lesson = LessonManager.nextLesson(for: chapter) {
                return (chapter, lesson)
            }
        }
        return nil
    }
}

// MARK: - Lesson Tray

struct LessonTrayView: View {
    let chapter: ChapterList
    let onLessonLaunched: () -> Void

    @State private var lessons: [Lesson] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lessons")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // Wrap lessons into rows of 4
            let rows = lessons.chunked(into: 4)
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    ForEach(lessons[rowIndex * 4 ..< min(rowIndex * 4 + 4, lessons.count)]) { lesson in
                        LessonBubble(lesson: lesson, onTap: {
                            onLessonLaunched()
                        })
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .onAppear {
            lessons = LessonManager.lessons(for: chapter)
        }
    }
}

// MARK: - Lesson Bubble

struct LessonBubble: View {
    let lesson: Lesson
    let onTap: () -> Void

    var body: some View {
        NavigationLink {
            if lesson.isUnlocked {
                WordLearningView(
                    viewModel: LearningViewModel(words: lesson.words),
                    currentChapter: ChapterList.allCases[lesson.chapterIndex],
                    lessonIndex: lesson.id
                )
            }
        } label: {
            ZStack {
                Circle()
                    .fill(bubbleFill)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(borderColor, lineWidth: 2))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)

                if lesson.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else if !lesson.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("\(lesson.displayNumber)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!lesson.isUnlocked)
        .simultaneousGesture(TapGesture().onEnded { if lesson.isUnlocked { onTap() } })
    }

    private var bubbleFill: LinearGradient {
        if lesson.isComplete {
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        } else if lesson.isUnlocked {
            return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var borderColor: Color {
        lesson.isComplete ? .green.opacity(0.6) : (lesson.isUnlocked ? .blue.opacity(0.4) : .gray.opacity(0.3))
    }
}

// MARK: - Connector With Progress (unchanged)

struct ConnectorWithProgress: View {
    var progress: Double
    var isLeftAligned: Bool

    var body: some View {
        ZStack {
            PathConnector(isLeftAligned: isLeftAligned)
                .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            PathConnector(isLeftAligned: isLeftAligned)
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .shadow(color: .blue.opacity(0.4 * progress), radius: 6 * progress)
                .animation(.easeInOut(duration: 1.2), value: progress)

            if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.appBackground.opacity(0.7)))
                    .offset(y: 20)
                    .opacity(progress > 0.03 ? 1 : 0)
                    .animation(.easeInOut, value: progress)
            }
        }
    }
}

// MARK: - Path Connector Shape (unchanged)

struct PathConnector: Shape {
    var isLeftAligned: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isLeftAligned {
            path.move(to: CGPoint(x: rect.midX + 40, y: 0))
            path.addCurve(
                to: CGPoint(x: rect.midX - 40, y: rect.maxY),
                control1: CGPoint(x: rect.maxX, y: rect.midY - 20),
                control2: CGPoint(x: rect.minX, y: rect.midY + 20)
            )
        } else {
            path.move(to: CGPoint(x: rect.midX - 40, y: 0))
            path.addCurve(
                to: CGPoint(x: rect.midX + 40, y: rect.maxY),
                control1: CGPoint(x: rect.minX, y: rect.midY - 20),
                control2: CGPoint(x: rect.maxX, y: rect.midY + 20)
            )
        }
        return path
    }
}

// MARK: - Locked Chapter Screen (unchanged)

struct LockedChapterView: View {
    let chapter: ChapterList

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.7))
            Text("Complete the previous chapter to unlock \"\(chapter.title)\"")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.headline)
                .padding()
        }
        .navigationTitle(chapter.title)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Up Next Card

struct UpNextCard: View {
    /// The next lesson to continue, or nil if everything is complete.
    let data: (chapter: ChapterList, lesson: Lesson)?

    var body: some View {
        if let data = data {
            // ── Active card ───────────────────────────────────────────────
            NavigationLink {
                WordLearningView(
                    viewModel: LearningViewModel(words: data.lesson.words),
                    currentChapter: data.chapter,
                    lessonIndex: data.lesson.id
                )
            } label: {
                ZStack(alignment: .bottomLeading) {
                    // Dark gradient background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "1A202C"), Color(hex: "2D3748")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.07), Color.clear],
                                        center: .topTrailing,
                                        startRadius: 0,
                                        endRadius: 200
                                    )
                                )
                        )

                    VStack(alignment: .leading, spacing: 10) {
                        // Tag pill
                        Text("UP NEXT")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1.5)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.white.opacity(0.15))
                            )

                        // Chapter + lesson title
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.chapter.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            Text("Lesson \(data.lesson.displayNumber)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        // Subtitle
                        Text("\(data.lesson.totalWords) words to learn")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.bottom, 4)

                        // Start button label (not a real Button — NavigationLink handles tap)
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.bold))
                            Text("Start Lesson")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white))
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

        } else {
            // ── All caught up card ────────────────────────────────────────
            HStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("All caught up!")
                        .font(.headline)
                    Text("You’ve completed all available lessons.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Previews

#Preview("Chapter Path") {
    ChapterPathView()
}

#Preview("Up Next Card – Active") {
    NavigationStack {
        let lesson = Lesson(id: 2, chapterIndex: 0,
                            words: [], isUnlocked: true, isComplete: false)
        UpNextCard(data: (.la_strada, lesson))
            .padding()
    }
}

#Preview("Up Next Card – Complete") {
    UpNextCard(data: nil)
        .padding()
}

#Preview("Lesson Tray") {
    NavigationStack {
        LessonTrayView(chapter: .la_strada, onLessonLaunched: {})
            .padding()
    }
}

#Preview("Lesson Bubble – States") {
    HStack(spacing: 16) {
        LessonBubble(
            lesson: Lesson(id: 0, chapterIndex: 0,
                           words: [], isUnlocked: true, isComplete: false),
            onTap: {}
        )
        LessonBubble(
            lesson: Lesson(id: 1, chapterIndex: 0,
                           words: [], isUnlocked: true, isComplete: true),
            onTap: {}
        )
        LessonBubble(
            lesson: Lesson(id: 2, chapterIndex: 0,
                           words: [], isUnlocked: false, isComplete: false),
            onTap: {}
        )
    }
    .padding()
}
