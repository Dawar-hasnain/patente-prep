//
//  SpeechManager.swift
//  Patente-Learning
//
//  Lightweight singleton wrapping AVSpeechSynthesizer.
//  Speaks Italian words aloud using the device's built-in TTS engine —
//  no API key, no network request, works fully offline.
//

import AVFoundation

final class SpeechManager {

    static let shared = SpeechManager()
    private init() {}

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Public API

    /// Speak a word or phrase in Italian.
    /// Interrupts any currently-playing speech immediately.
    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Stop anything already speaking
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // Prefer the Italian locale; falls back to any available Italian voice
        utterance.voice = AVSpeechSynthesisVoice(language: "it-IT")
            ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("it") }

        // Slightly slower than default — clarity over speed for learners
        utterance.rate          = 0.42
        utterance.pitchMultiplier = 1.0
        utterance.volume        = 1.0

        synthesizer.speak(utterance)
    }

    /// Stop any in-progress speech.
    func stop() {
        synthesizer.stopSpeaking(at: .word)
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }
}
