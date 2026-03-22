////
////  ChapterSelectionView.swift
////  Patente-Learning
////
////  Created by Dawar Hasnain on 07/11/25.
////
//import SwiftUI
//
//struct ChapterSelectionView: View {
//    @State private var showAlert = false
//    @State private var errorMessage = ""
//    @State private var progressDict: [ChapterList: Double] = [:]
//    
//    var body: some View {
//        NavigationStack {
//            VStack {
//                ScrollView {
//                    VStack(spacing: 20) {
//                        ForEach(ChapterList.allCases) { chapter in
//                            let result = Result { try loadChapterSafely(chapter.filename) }
//                            switch result {
//                            case .success(let chapterData):
//                                let progress = progressDict[chapter] ?? 0
//                                let isUnlocked = isChapterUnlocked(chapter)
//                                
//                                // ✅ Use NavigationLink again for proper back navigation
//                                NavigationLink {
//                                    if isUnlocked {
//                                        WordLearningView(
//                                            viewModel: LearningViewModel(words: chapterData.words),
//                                            currentChapter: chapter
//                                        )
//                                    } else {
//                                        LockedChapterView(chapter: chapter)
//                                    }
//                                } label: {
//                                    ChapterRow(chapter: chapter)
//                                        .opacity(isUnlocked ? 1.0 : 0.55)
//                                        .grayscale(isUnlocked ? 0 : 0.4)
////                                        .overlay(alignment: .topTrailing) {
////                                            if !isUnlocked {
////                                                Image(systemName: "lock.fill")
////                                                    .foregroundColor(.secondary.opacity(0.7))
////                                                    .font(.system(size: 18))
////                                                    .padding(12)
////                                            }
////                                        }
//                                }
//                                .buttonStyle(.plain)
//                                .disabled(!isUnlocked)
//                                .animation(.easeInOut(duration: 0.25), value: isUnlocked)
//                                
//                            case .failure(let error):
//                                Button {
//                                    if let err = error as? LocalizedError {
//                                        errorMessage = err.errorDescription ?? "Unknown error."
//                                    } else {
//                                        errorMessage = error.localizedDescription
//                                    }
//                                    showAlert = true
//                                } label: {
//                                    ChapterRow(chapter: chapter)
//                                        .opacity(0.6)
//                                }
//                                .buttonStyle(.plain)
//                            }
//                        }
//                    }
//                    .padding(.vertical, 30)
//                }
//                
//                Button(action: resetProgress) {
//                    Label("Reset Progress", systemImage: "arrow.counterclockwise.circle")
//                        .font(.headline)
//                        .foregroundColor(.red)
//                }
//                .padding(.bottom, 20)
//            }
//            .background(Color.appBackground.ignoresSafeArea())
//            .navigationTitle("📘 Patente Chapters")
//            .alert("⚠️ Chapter Error", isPresented: $showAlert) {
//                Button("OK", role: .cancel) { }
//            } message: {
//                Text(errorMessage)
//            }
//        }
//        .id(UUID()) // refresh progress when returning
//        .onAppear(perform: updateAllProgress)
//    }
//    
//    // MARK: - Helpers
//    
//    private func updateAllProgress() {
//        var dict: [ChapterList: Double] = [:]
//        for chapter in ChapterList.allCases {
//            dict[chapter] = ProgressManager.shared.progress(for: chapter)
//        }
//        progressDict = dict
//    }
//    
//    private func isChapterUnlocked(_ chapter: ChapterList) -> Bool {
//        let allChapters = ChapterList.allCases
//        guard let index = allChapters.firstIndex(of: chapter) else { return false }
//        if index == 0 { return true }
//        
//        let previous = allChapters[index - 1]
//        let previousProgress = progressDict[previous] ?? 0.0
//        return previousProgress >= 0.7
//    }
//    
//    private func resetProgress() {
//        UserDefaults.standard.removeObject(forKey: "learnedWords")
//        updateAllProgress()
//        print("🔁 All progress reset.")
//    }
//}
//
////Commented to test ChapterPathView
//
//// MARK: - Placeholder View for Locked Chapters
////struct LockedChapterView: View {
////    let chapter: ChapterList
////    var body: some View {
////        VStack(spacing: 16) {
////            Image(systemName: "lock.fill")
////                .font(.system(size: 50))
////                .foregroundColor(.gray.opacity(0.7))
////            Text("Complete the previous chapter to unlock “\(chapter.title)”")
////                .multilineTextAlignment(.center)
////                .foregroundColor(.secondary)
////                .font(.headline)
////                .padding()
////        }
////        .navigationTitle(chapter.title)
////        .background(Color.appBackground.ignoresSafeArea())
////    }
////}
