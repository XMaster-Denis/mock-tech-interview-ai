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
        static let gpt4oMini = "gpt-4o-mini"
        static let gpt41 = "gpt-4.1"
        static let gpt41Mini = "gpt-4.1-mini"
        static let whisperMini = "gpt-4o-mini-transcribe"
        static let whisper = "whisper-1"
        static let whisper4o = "gpt-4o-transcribe"
        static let tts = "tts-1"
        static let ttsHd = "tts-1-hd"
        
        static let chatModels = [gpt4o, gpt4oMini, gpt41, gpt41Mini]
        static let whisperModels = [whisperMini, whisper4o, whisper]
        static let ttsModels = [tts, ttsHd]
    }
    
    enum Voice {
        static let alloy = "alloy"
        static let echo = "echo"
        static let fable = "fable"
        static let onyx = "onyx"
        static let nova = "nova"
        static let shimmer = "shimmer"
        
        static let all = [alloy, echo, fable, onyx, nova, shimmer]
    }
}

enum UserDefaultsKeys {
    static let apiKey = "openai_api_key"
    static let selectedLanguage = "selected_language"
    static let selectedVoice = "selected_voice"
    static let selectedChatModel = "selected_chat_model"
    static let selectedWhisperModel = "selected_whisper_model"
    static let selectedTTSModel = "selected_tts_model"
    static let voiceThreshold = "voice_threshold"
    static let silenceTimeout = "silence_timeout"
    static let minSpeechLevel = "min_speech_level"
    static let allowTTSInterruption = "allow_tts_interruption"
}
