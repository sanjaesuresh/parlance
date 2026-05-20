// ParlanceTests/TranscriptCensorTests.swift
import XCTest
@testable import Parlance

final class TranscriptCensorTests: XCTestCase {
    func testCensorsKnownProfanityWordBoundary() {
        let result = TranscriptCensor.censor("I think this fucking sucks")
        XCTAssertEqual(result, "I think this f****** sucks")
    }

    func testCaseInsensitive() {
        let result = TranscriptCensor.censor("What the FUCK")
        // Preserves original case of first letter.
        XCTAssertEqual(result, "What the F***")
    }

    func testDoesNotMatchSubstrings() {
        // "Scunthorpe" must not match "cunt"; "classic" must not match anything.
        let result = TranscriptCensor.censor("I went to Scunthorpe and saw classics")
        XCTAssertEqual(result, "I went to Scunthorpe and saw classics")
    }

    func testEmptyAndCleanInput() {
        XCTAssertEqual(TranscriptCensor.censor(""), "")
        XCTAssertEqual(TranscriptCensor.censor("hello world"), "hello world")
    }

    func testCensorsMultipleOccurrences() {
        let result = TranscriptCensor.censor("shit, shit, and more shit")
        XCTAssertEqual(result, "s***, s***, and more s***")
    }

    func testPunctuationAdjacentToWord() {
        let result = TranscriptCensor.censor("Well, fuck! That hurt.")
        XCTAssertEqual(result, "Well, f***! That hurt.")
    }
}
