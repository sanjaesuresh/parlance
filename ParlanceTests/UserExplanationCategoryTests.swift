// ParlanceTests/UserExplanationCategoryTests.swift
import Testing
import Foundation
import SwiftData
@testable import Parlance

@Suite("User.lastExplanationCategory")
struct UserExplanationCategoryTests {

    @Test("new User defaults to .any")
    func newUser_defaultsToAny() throws {
        let user = User(displayName: "Test User", avatarEmoji: "😀")
        #expect(user.lastExplanationCategory == .any)
    }

    @Test("setting lastExplanationCategory to .tech updates raw value")
    func setCategory_updatesRaw() throws {
        let user = User(displayName: "Test User", avatarEmoji: "😀")
        user.lastExplanationCategory = .tech
        #expect(user.lastExplanationCategoryRaw == "tech")
    }

    @Test("unknown raw value falls back to .any")
    func unknownRaw_fallsBackToAny() throws {
        let user = User(displayName: "Test User", avatarEmoji: "😀")
        user.lastExplanationCategoryRaw = "garbage_value_from_future_version"
        #expect(user.lastExplanationCategory == .any)
    }
}
