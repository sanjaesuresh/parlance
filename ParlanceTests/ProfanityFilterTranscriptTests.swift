// ParlanceTests/ProfanityFilterTranscriptTests.swift
import XCTest
@testable import Parlance

final class ProfanityFilterTranscriptTests: XCTestCase {
    func testCleanTranscriptScansEmpty() {
        let r = ProfanityFilter.scanTranscript("This is a normal job interview answer.")
        XCTAssertEqual(r.profaneWordCount, 0)
        XCTAssertEqual(r.totalWords, 7) // "This is a normal job interview answer" = 7 words
        XCTAssertFalse(r.containsSlur)
    }

    func testWordBoundaryDoesNotMatchSubstring() {
        // Scunthorpe must not match cunt; class must not match ass.
        let r = ProfanityFilter.scanTranscript("Scunthorpe class assignment classics")
        XCTAssertEqual(r.profaneWordCount, 0)
        XCTAssertFalse(r.containsSlur)
    }

    func testCountsProfanityCaseInsensitive() {
        let r = ProfanityFilter.scanTranscript("Shit, this FUCKING sucks shit")
        // Counts: shit, fucking, shit = 3
        XCTAssertEqual(r.profaneWordCount, 3)
    }

    func testDetectsSlur() {
        let r = ProfanityFilter.scanTranscript("That guy is a retard honestly")
        XCTAssertTrue(r.containsSlur)
    }

    func testRatioComputation() {
        // 2 profane out of 4 total → 0.5
        let r = ProfanityFilter.scanTranscript("shit damn hello world")
        // Note: "damn" is NOT in the denylist; only "shit" is profane here.
        XCTAssertEqual(r.profaneWordCount, 1)
        XCTAssertEqual(r.totalWords, 4)
        XCTAssertEqual(r.ratio, 0.25, accuracy: 0.001)
    }

    func testEmptyTranscript() {
        let r = ProfanityFilter.scanTranscript("")
        XCTAssertEqual(r.totalWords, 0)
        XCTAssertEqual(r.profaneWordCount, 0)
        XCTAssertEqual(r.ratio, 0.0, accuracy: 0.001)
    }
}
