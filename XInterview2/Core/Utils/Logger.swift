//
//  Logger.swift
//  XInterview2
//
//  Logging utility with timestamp
//

import Foundation

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
    
    // MARK: - Public Methods
    
    static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("[\(timestamp())] [\(filename):\(function):\(line)] \(message)")
    }
    
    static func audio(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("🔊 \(message)", file: file, function: function, line: line)
    }
    
    static func voice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("🎤 \(message)", file: file, function: function, line: line)
    }
    
    static func tts(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("🔊 \(message)", file: file, function: function, line: line)
    }
    
    static func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("🌐 \(message)", file: file, function: function, line: line)
    }
    
    static func state(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("🔄 \(message)", file: file, function: function, line: line)
    }
    
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        if let err = error {
            log("❌ \(message): \(err.localizedDescription)", file: file, function: function, line: line)
        } else {
            log("❌ \(message)", file: file, function: function, line: line)
        }
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("⚠️ \(message)", file: file, function: function, line: line)
    }
    
    static func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("✅ \(message)", file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("ℹ️ \(message)", file: file, function: function, line: line)
    }
}
