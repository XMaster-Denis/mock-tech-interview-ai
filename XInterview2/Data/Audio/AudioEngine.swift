//
//  AudioEngine.swift
//  XInterview2
//
//  Audio recording and playback using AVFoundation
//

import AVFoundation

protocol AudioEngineProtocol: AnyObject {
    var audioData: Data? { get }
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    
    func startRecording() throws
    func stopRecording() throws
    func playAudio(_ data: Data) throws
    func stopPlayback()
}

class AudioEngine: NSObject, AudioEngineProtocol {
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var audioFile: AVAudioFile?
    
    var audioData: Data?
    private(set) var isRecording: Bool = false
    private(set) var isPlaying: Bool = false
    
    private var currentRecordingURL: URL?
    
    // MARK: - Recording
    
    func startRecording() throws {
        guard !isRecording else {
            return
        }
        
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        
        // Configure format for recording
        let format = inputNode.outputFormat(forBus: 0)
        
        // Create unique file to avoid conflicts
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        currentRecordingURL = audioURL
        
        audioFile = try AVAudioFile(forWriting: audioURL, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self, let file = self.audioFile else { return }
            try? file.write(from: buffer)
        }
        
        try audioEngine?.start()
        isRecording = true
    }
    
    func stopRecording() throws {
        guard isRecording else {
            return
        }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Read the audio file data
        if let file = audioFile {
            audioData = try Data(contentsOf: file.url)
        }
        
        isRecording = false
        audioEngine = nil
        
        // Clean up the recording file after reading
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
            currentRecordingURL = nil
        }
    }
    
    // MARK: - Playback
    
    func playAudio(_ data: Data) throws {
        guard !isPlaying else {
            return
        }
        
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioEngine: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
    }
}
