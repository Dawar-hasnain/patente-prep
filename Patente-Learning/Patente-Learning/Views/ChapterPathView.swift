//
//  ChapterPathView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct ChapterPathView: View {
    @State private var progressDict: [ChapterList: Double] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        
                        // 🔹 Review banner (now perfectly placed under title)
                        GeometryReader{ geo in
                            if let pending = nextPendingReview() {
                                
                                let offset = geo.frame(in: .global).minY
                                let fade = max(0, min(1, 1 - (offset / 500))) // 0–80pt fade range
                                
                                Button(action: { launchPendingReview(for: pending.chapter) }) {
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
                        .frame(height: 70) // Fix GeometryReader height
                        .zIndex(1)
                        
                        // 🔹 Chapter Path Content
                        VStack(spacing: 80) {
                            ForEach(Array(ChapterList.allCases.enumerated()), id: \.element) { index, chapter in
                                let progress = progressDict[chapter] ?? 0
                                let isUnlocked = isChapterUnlocked(chapter)
                                
                                VStack(spacing: 0) {
                                    // Chapter Node
                                    HStack {
                                        if index.isMultiple(of: 2) {
                                            Spacer()
                                            ChapterNode(
                                                chapter: chapter,
                                                progress: progress,
                                                isUnlocked: isUnlocked,
                                                animatePulse: isUnlocked && progress < 1.0
                                            )
                                        } else {
                                            ChapterNode(
                                                chapter: chapter,
                                                progress: progress,
                                                isUnlocked: isUnlocked,
                                                animatePulse: isUnlocked && progress < 1.0
                                            )
                                            Spacer()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Connector (below each node except last)
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
                
                // 🔁 Floating Reset Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: resetProgress) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.red.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                .padding()
                        }
                        .accessibilityLabel("Reset progress")
                        
                        // Unlock All
                            Button(action: unlockAllChapters) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(.green.opacity(0.9))
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                            .accessibilityLabel("Unlock all chapters")
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("📘 Patente Chapters")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: updateAllProgress)
        

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
        if index == 0 { return true } // first chapter always unlocked
        
        let previous = allChapters[index - 1]
        let previousProgress = progressDict[previous] ?? 0.0
        return previousProgress >= 0.7 // unlock threshold (70%)
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
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let root = UIHostingController(
                rootView: ReviewSessionView(
                    chapter: chapter,
                    currentProgress: 0.0,
                    onCompletion: { passed, score in
                        ProgressManager.shared.updateCheckpoint(
                            for: chapter,
                            section: 1,
                            passed: passed,
                            score: score
                        )
                        window.rootViewController = UIHostingController(
                            rootView: ChapterPathView()
                        )
                        window.makeKeyAndVisible()
                    }
                )
            )
            window.rootViewController = root
            window.makeKeyAndVisible()
        }
    }
    
    // MARK: - Reset
    
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
    
    private func unlockAllChapters() {
        ProgressManager.shared.unlockAllChaptersForTesting()
        withAnimation(.spring()) {
            updateAllProgress()
        }
    }

}

// MARK: - Connector With Progress + Percentage Label
struct ConnectorWithProgress: View {
    var progress: Double
    var isLeftAligned: Bool

    var body: some View {
        ZStack {
            // Base gray line
            PathConnector(isLeftAligned: isLeftAligned)
                .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            // Animated gradient line
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

            // Progress label
            if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.appBackground.opacity(0.7))
                    )
                    .offset(y: 20)
                    .opacity(progress > 0.03 ? 1 : 0)
                    .animation(.easeInOut, value: progress)
            }
        }
    }
}

// MARK: - Connector Shape
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

// MARK: - Chapter Node (Bubble)
struct ChapterNode: View {
    let chapter: ChapterList
    let progress: Double
    let isUnlocked: Bool
    var animatePulse: Bool

    @State private var pulse = false

    var body: some View {
        NavigationLink {
            if isUnlocked {
                if ProgressManager.shared.isChapterMastered(chapter) {
                    WordLearningView(
                        viewModel: LearningViewModel(words: loadChapter(chapter.filename).words),
                        currentChapter: chapter
                    )
                } else if ProgressManager.shared.hasAttemptedFinalReview(chapter) {
                    FinalChapterReviewView(chapter: chapter)
                } else {
                    WordLearningView(
                        viewModel: LearningViewModel(words: loadChapter(chapter.filename).words),
                        currentChapter: chapter
                    )
                }
            } else {
                LockedChapterView(chapter: chapter)
            }
        }
        label: {
            ZStack {
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
                            .stroke(isUnlocked ? Color.blue : .gray.opacity(0.4), lineWidth: 4)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                    .scaleEffect(pulse && animatePulse ? 1.08 : 1.0)
                    .animation(
                        animatePulse
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                        value: pulse
                    )
                    .onAppear {
                        if animatePulse { pulse = true }
                    }

                VStack(spacing: 6) {
                    if ProgressManager.shared.isChapterMastered(chapter) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.yellow)
                    } else if ProgressManager.shared.hasAttemptedFinalReview(chapter) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: isUnlocked ? "book.fill" : "lock.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }

                    Text(chapter.shortTitle)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
}

// MARK: - Locked Chapter Screen
struct LockedChapterView: View {
    let chapter: ChapterList

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.7))
            Text("Complete the previous chapter to unlock “\(chapter.title)”")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.headline)
                .padding()
        }
        .navigationTitle(chapter.title)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
