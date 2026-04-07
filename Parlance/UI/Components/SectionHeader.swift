import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppFonts.bodyMedium(11))
            .foregroundStyle(AppColors.dim)
            .kerning(1.2)
    }
}
