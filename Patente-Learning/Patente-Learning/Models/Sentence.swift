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
