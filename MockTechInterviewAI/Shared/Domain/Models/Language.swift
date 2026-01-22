//
//  Language.swift
//  XInterview2
//
//  Supported interview languages
//

import Foundation

enum Language: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case russian = "ru"
    case german = "de"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .german: return "Deutsch"
        }
    }
    
    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .russian: return Locale(identifier: "ru_RU")
        case .german: return Locale(identifier: "de_DE")
        }
    }
}
