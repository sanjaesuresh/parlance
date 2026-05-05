import SwiftUI

enum AppFonts {
    static func display(_ size: CGFloat) -> Font {
        .custom("Fraunces72pt-Bold", size: size, relativeTo: .title)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size, relativeTo: .body)
    }

    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size, relativeTo: .body)
    }

    static func bodyBold(_ size: CGFloat) -> Font {
        .custom("Inter-Bold", size: size, relativeTo: .body)
    }
}
