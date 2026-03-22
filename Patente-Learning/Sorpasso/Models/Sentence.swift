//
//  Sentence.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import Foundation

struct Sentence: Identifiable, Codable{
    let id : UUID = UUID()
    let text: String
    let answer: Bool
}

struct SentenceWord: Identifiable {
    let id = UUID()
    let word: String
    let translation: String?
    let partOfSpeech: String? = nil
    let audioURL: String? = nil
}
