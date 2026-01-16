//
//  HelpModeDetectorTests.swift
//  XInterview2Tests
//

import XCTest
@testable import XInterview2

final class HelpModeDetectorTests: XCTestCase {
    func testDetectsFullSolutionInRussian() {
        let mode = HelpModeDetector.detectHelpMode("я не умею", language: .russian)
        XCTAssertEqual(mode, .fullSolution)
    }
    
    func testDetectsHintOnlyInRussian() {
        let mode = HelpModeDetector.detectHelpMode("дай подсказку", language: .russian)
        XCTAssertEqual(mode, .hintOnly)
    }
    
    func testDetectsFullSolutionInEnglish() {
        let mode = HelpModeDetector.detectHelpMode("I give up", language: .english)
        XCTAssertEqual(mode, .fullSolution)
    }
}
