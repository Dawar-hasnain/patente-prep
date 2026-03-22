//
//  ChapterList.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import Foundation

enum ChapterList: String, CaseIterable, Identifiable, Codable {
    case la_strada = "01_la_strada"
    case segnaletica_stradale = "02_segnaletica_stradale"
    case norme_di_comportamento = "03_norme_di_comportamento"
    case il_veicolo_a_motore = "04_il_veicolo_a_motore"
    case i_veicoli = "05_i_veicoli"
    case equipaggiamento_dei_veicoli = "06_equipaggiamento_dei_veicoli"
    case sicurezza_e_inquinamento = "07_sicurezza_e_inquinamento"
    case incidenti_e_assicurazione = "08_incidenti_e_assicurazione"
    case primo_soccorso = "09_primo_soccorso"
    case documenti = "10_documenti"
    
    var id: String { rawValue }
    
    /// Readable display title
    var title: String {
        switch self {
        case .la_strada: return "La Strada"
        case .segnaletica_stradale: return "Segnaletica Stradale"
        case .norme_di_comportamento: return "Norme di Comportamento"
        case .il_veicolo_a_motore: return "Il Veicolo a Motore"
        case .i_veicoli: return "I Veicoli"
        case .equipaggiamento_dei_veicoli: return "Equipaggiamento dei Veicoli"
        case .sicurezza_e_inquinamento: return "Sicurezza e Inquinamento"
        case .incidenti_e_assicurazione: return "Incidenti e Assicurazione"
        case .primo_soccorso: return "Primo Soccorso"
        case .documenti: return "Documenti"
        }
    }
    
    /// 👇 Shorter name for circular node display
        var shortTitle: String {
            switch self {
            case .la_strada: return "Strada"
            case .documenti: return "Doc"
            case .segnaletica_stradale: return "Segnali"
            case .norme_di_comportamento: return "Norme"
            case .incidenti_e_assicurazione: return "Incid."
            case .il_veicolo_a_motore: return "Veicolo"
            case .equipaggiamento_dei_veicoli: return "Equip."
            case .sicurezza_e_inquinamento: return "Sicurezza"
            case .primo_soccorso: return "Soccorso"
            case .i_veicoli: return "Veicoli"
            }
        }
    
    /// Corresponding JSON filename
    var filename: String { rawValue }
}
