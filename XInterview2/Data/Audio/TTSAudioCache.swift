//
//  TTSAudioCache.swift
//  XInterview2
//
//  Stores TTS audio files for replay during an interview session
//

import Foundation

final class TTSAudioCache {
    static let folderName = "XInterviewTTS"
    
    private let fileManager = FileManager.default
    
    private var folderURL: URL {
        Self.folderURL
    }
    
    static var folderURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
    }
    
    func clear() {
        let url = folderURL
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func saveAudio(_ data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        let fileName = "tts_\(UUID().uuidString).mp3"
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            Logger.error("Failed to store TTS audio", error: error)
            return nil
        }
    }
    
    static func audioFileURL(for fileName: String) -> URL {
        folderURL.appendingPathComponent(fileName)
    }
}
