//
//  SyntaxToken.swift
//  XInterview2
//
//  Syntax highlighting token types and rules
//

import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Types of syntax tokens for highlighting
enum SyntaxTokenType {
    case keyword
    case string
    case comment
    case number
    case function
    case type
    case variable
    case `operator`
    case attribute
    case none
}

/// Represents a single highlighted token
struct SyntaxToken {
    let range: NSRange
    let type: SyntaxTokenType
    
    init(range: NSRange, type: SyntaxTokenType) {
        self.range = range
        self.type = type
    }
}

/// Represents a syntax highlighting rule
struct SyntaxRule {
    let type: SyntaxTokenType
    let pattern: NSRegularExpression
    
    init(type: SyntaxTokenType, pattern: String) throws {
        self.type = type
        self.pattern = try NSRegularExpression(pattern: pattern, options: [])
    }
}

/// Syntax highlighting theme colors
struct SyntaxTheme {
    static let xcodeDark = SyntaxTheme(
        backgroundColor: PlatformColor(hex: "#1E1E1E"),
        textColor: PlatformColor(hex: "#D4D4D4"),
        keywordColor: PlatformColor(hex: "#A960F7"),
        stringColor: PlatformColor(hex: "#4EBD81"),
        commentColor: PlatformColor(hex: "#7F848E"),
        numberColor: PlatformColor(hex: "#F4A261"),
        functionColor: PlatformColor(hex: "#4CA6FF"),
        typeColor: PlatformColor(hex: "#E06C75"),
        variableColor: PlatformColor(hex: "#9CDCFE"),
        operatorColor: PlatformColor(hex: "#D4D4D4"),
        attributeColor: PlatformColor(hex: "#FFD700")
    )
    
    let backgroundColor: PlatformColor
    let textColor: PlatformColor
    let keywordColor: PlatformColor
    let stringColor: PlatformColor
    let commentColor: PlatformColor
    let numberColor: PlatformColor
    let functionColor: PlatformColor
    let typeColor: PlatformColor
    let variableColor: PlatformColor
    let operatorColor: PlatformColor
    let attributeColor: PlatformColor
    
    func color(for tokenType: SyntaxTokenType) -> PlatformColor {
        switch tokenType {
        case .keyword:
            return keywordColor
        case .string:
            return stringColor
        case .comment:
            return commentColor
        case .number:
            return numberColor
        case .function:
            return functionColor
        case .type:
            return typeColor
        case .variable:
            return variableColor
        case .operator:
            return operatorColor
        case .attribute:
            return attributeColor
        case .none:
            return textColor
        }
    }
    
    func attributes(for tokenType: SyntaxTokenType, font: PlatformFont) -> [NSAttributedString.Key: Any] {
        return [
            .foregroundColor: color(for: tokenType),
            .font: font
        ]
    }
}
