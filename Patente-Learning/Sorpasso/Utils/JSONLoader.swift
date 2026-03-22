//
//  JSONLoader.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import Foundation

func loadChapter(_ name: String) -> Chapter {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
        print("⚠️ Warning: Missing file: \(name).json — loading fallback chapter.")
        return Chapter(
            chapter: "Missing File",
            words: [
                Words(italian: "Errore", english: "Error", type: "noun"),
                Words(italian: "File", english: "File", type: "noun"),
                Words(italian: "Mancante", english: "Missing", type: "adjective")
            ],
            sentences: nil
        )
    }
    
    do {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(Chapter.self, from: data)
        return decoded
    } catch {
        print("⚠️ Decoding error for file \(name).json: \(error.localizedDescription)")
        return Chapter(
            chapter: "Invalid JSON",
            words: [
                Words(italian: "Errore", english: "Error", type: "noun"),
                Words(italian: "File", english: "Corrotto", type: "adjective")
            ],
            sentences: nil
        )
    }
}

enum ChapterLoadError: LocalizedError {
    case fileNotFound(String)
    case decodeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "The file \(name).json was not found in the app bundle."
        case .decodeFailed(let name):
            return "Unable to read or decode \(name).json. The file may be corrupted."
        }
    }
}

func loadChapterSafely(_ name: String) throws -> Chapter {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
        throw ChapterLoadError.fileNotFound(name)
    }
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Chapter.self, from: data)
    } catch {
        throw ChapterLoadError.decodeFailed(name)
    }
}

