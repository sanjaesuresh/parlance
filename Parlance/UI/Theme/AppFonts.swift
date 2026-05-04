import SwiftUI

enum AppFonts {
    static func display(_ size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Bold", size: size, relativeTo: .title)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("DMSans-Regular", size: size, relativeTo: .body)
    }

    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("DMSans-Medium", size: size, relativeTo: .body)
    }

    static func bodyBold(_ size: CGFloat) -> Font {
        .custom("DMSans-Bold", size: size, relativeTo: .body)
    }
}
