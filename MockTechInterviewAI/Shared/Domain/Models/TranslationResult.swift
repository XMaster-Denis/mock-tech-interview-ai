//
//  TranslationResult.swift
//  XInterview2
//
//  AI translation payload for assistant messages
//

import Foundation

struct TranslationResult: Codable, Equatable {
    let translation: String
    let notes: String?
}
