//
//  Chapter.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import Foundation

struct Chapter: Identifiable, Codable{
    let id : UUID = UUID()
    let chapter: String
    let words: [Words]
    let sentences: [Sentence]?
}
