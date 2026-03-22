//
//  RecallQuestions.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import Foundation

struct RecallQuestion: Identifiable {
    let id = UUID()
    let sentence: String
    let answer: String
    var userInput: String = ""
}
