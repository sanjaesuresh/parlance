import Foundation

enum ProfanityFilter {
    /// Returns nil if the input is acceptable, or a user-facing error message if rejected.
    static func validate(_ input: String, fieldName: String) -> String? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let denyList: Set<String> = [
            // English deny-list — conservative; satisfies App Review Guideline 1.2.
            "fuck", "shit", "cunt", "bitch", "asshole", "nigger", "faggot", "retard",
            "tranny", "kike", "spic", "chink", "whore", "slut", "rape", "pedo",
            "nazi", "hitler"
        ]
        let words = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for word in words {
            if denyList.contains(word) {
                return "\(fieldName) contains language that isn't allowed."
            }
        }
        for entry in denyList {
            if normalized.contains(entry) {
                return "\(fieldName) contains language that isn't allowed."
            }
        }
        return nil
    }
}
