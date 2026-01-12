//
//  SyntaxToken.swift
//  XInterview2
//
//  Syntax highlighting token types and rules
//

import Foundation
import AppKit

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
        backgroundColor: NSColor(hex: "#1E1E1E"),
        textColor: NSColor(hex: "#D4D4D4"),
        keywordColor: NSColor(hex: "#A960F7"),
        stringColor: NSColor(hex: "#4EBD81"),
        commentColor: NSColor(hex: "#7F848E"),
        numberColor: NSColor(hex: "#F4A261"),
        functionColor: NSColor(hex: "#4CA6FF"),
        typeColor: NSColor(hex: "#E06C75"),
        variableColor: NSColor(hex: "#9CDCFE"),
        operatorColor: NSColor(hex: "#D4D4D4"),
        attributeColor: NSColor(hex: "#FFD700")
    )
    
    let backgroundColor: NSColor
    let textColor: NSColor
    let keywordColor: NSColor
    let stringColor: NSColor
    let commentColor: NSColor
    let numberColor: NSColor
    let functionColor: NSColor
    let typeColor: NSColor
    let variableColor: NSColor
    let operatorColor: NSColor
    let attributeColor: NSColor
    
    func color(for tokenType: SyntaxTokenType) -> NSColor {
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
    
    func attributes(for tokenType: SyntaxTokenType, font: NSFont) -> [NSAttributedString.Key: Any] {
        return [
            .foregroundColor: color(for: tokenType),
            .font: font
        ]
    }
}

// MARK: - NSColor Extension

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
