// Parlance/Core/Models/WordSegment.swift
import Foundation

struct WordSegment {
    let word: String
    let timestamp: TimeInterval   // seconds from recording start
    let duration: TimeInterval    // how long the word lasted
}
