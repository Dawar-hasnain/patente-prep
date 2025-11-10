//
//  Words.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import Foundation

struct Example: Identifiable, Codable {
    let id = UUID()
    let sentence: String
    let label: String   // "vero" or "falso"
}

struct Words: Identifiable, Codable{
    let id : UUID = UUID()
    let italian: String
    let english: String
    let type: String?
    let examples: [Example]?
    let usage_count: Int?
    
    init(
            italian: String,
            english: String,
            type: String? = nil,
            examples: [Example]? = nil,
            usage_count: Int? = nil
        ) {
            self.italian = italian
            self.english = english
            self.type = type
            self.examples = examples
            self.usage_count = usage_count
        }
}
