//
//  APIConstants.swift
//  XInterview2
//
//  Centralized API configuration
//

import Foundation

enum APIConstants {
    static let baseURL = "https://api.openai.com/v1"
    static let chatEndpoint = "/chat/completions"
    static let transcriptionEndpoint = "/audio/transcriptions"
    static let ttsEndpoint = "/audio/speech"
    
    enum Model {
        static let gpt4o = "gpt-4o"
        static let whisper = "whisper-1"
        static let tts = "tts-1"
    }
    
    enum Voice {
        static let alloy = "alloy"
        static let echo = "echo"
        static let fable = "fable"
        static let onyx = "onyx"
        static let nova = "nova"
        static let shimmer = "shimmer"
    }
}

enum UserDefaultsKeys {
    static let apiKey = "openai_api_key"
    static let selectedLanguage = "selected_language"
    static let selectedVoice = "selected_voice"
    static let voiceThreshold = "voice_threshold"
    static let silenceTimeout = "silence_timeout"
    static let minSpeechLevel = "min_speech_level"
    static let allowTTSInterruption = "allow_tts_interruption"
}
