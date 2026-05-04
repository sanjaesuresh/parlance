import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppFonts.bodyBold(11))
            .foregroundStyle(AppColors.sub)
            .kerning(1.2)
    }
}
