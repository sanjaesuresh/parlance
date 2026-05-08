import Foundation

enum CategoryTier: String, Codable {
    case general
    case industry
    case knowledge
}

enum ExplanationCategory: String, CaseIterable, Codable {
    case any

    // Industries
    case tech
    case healthcare
    case finance
    case marketing
    case education
    case legal
    case realEstate
    case consulting
    case mediaEntertainment

    // Knowledge domains
    case business
    case history
    case science
    case politics
    case philosophy
    case psychology
    case economics
    case healthWellness

    var displayName: String {
        switch self {
        case .any: "Any topic"
        case .tech: "Tech / Software"
        case .healthcare: "Healthcare"
        case .finance: "Finance"
        case .marketing: "Marketing"
        case .education: "Education"
        case .legal: "Legal"
        case .realEstate: "Real Estate"
        case .consulting: "Consulting"
        case .mediaEntertainment: "Media / Entertainment"
        case .business: "Business"
        case .history: "History"
        case .science: "Science"
        case .politics: "Politics"
        case .philosophy: "Philosophy"
        case .psychology: "Psychology"
        case .economics: "Economics"
        case .healthWellness: "Health & Wellness"
        }
    }

    var tier: CategoryTier {
        switch self {
        case .any:
            return .general
        case .tech, .healthcare, .finance, .marketing, .education,
             .legal, .realEstate, .consulting, .mediaEntertainment:
            return .industry
        case .business, .history, .science, .politics,
             .philosophy, .psychology, .economics, .healthWellness:
            return .knowledge
        }
    }
}
