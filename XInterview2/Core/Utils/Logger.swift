//
//  Logger.swift
//  XInterview2
//
//  Logging utility with timestamp and log levels
//

import Foundation

// MARK: - Log Level

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    static let current: LogLevel = .info // Set to .debug for verbose logging
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Logger

class Logger {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private static func timestamp() -> String {
        return dateFormatter.string(from: Date())
    }
    
    private static func shouldLog(level: LogLevel) -> Bool {
        return level.rawValue >= LogLevel.current.rawValue
    }
    
    private static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog(level: level) else { return }
        
        let filename = (file as NSString).lastPathComponent
        let prefix: String
        switch level {
        case .debug:
            prefix = "🔧"
        case .info:
            prefix = "ℹ️"
        case .warning:
            prefix = "⚠️"
        case .error:
            prefix = "❌"
        }
        
        print("[\(timestamp())] [\(filename):\(function):\(line)] \(prefix) \(message)")
    }
    
    // MARK: - Public Methods
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fullMessage = if let err = error {
            "\(message): \(err.localizedDescription)"
        } else {
            message
        }
        log(fullMessage, level: .error, file: file, function: function, line: line)
    }
    
    static func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    // MARK: - Deprecated Methods (kept for compatibility, reduced output)
    
    static func audio(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🔊 \(message)", file: file, function: function, line: line)
    }
    
    static func voice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🎤 \(message)", file: file, function: function, line: line)
    }
    
    static func tts(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🔊 \(message)", file: file, function: function, line: line)
    }
    
    static func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🌐 \(message)", file: file, function: function, line: line)
    }
    
    static func state(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🔄 \(message)", file: file, function: function, line: line)
    }
}
