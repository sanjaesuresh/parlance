import Foundation

enum PromotionStatus: Equatable, Sendable {
    case safe
    case eligibleForPromotion(xpRemaining: Int)
    case atRiskOfDemotion
    case atTop
}
