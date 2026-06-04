import SwiftUI

struct DifficultyChangeSheet: View {
    @Binding var selectedLevel: Int
    let isPro: Bool
    let onConfirm: (Int) -> Void
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingLevel: Int

    init(
        selectedLevel: Binding<Int>,
        isPro: Bool,
        onConfirm: @escaping (Int) -> Void,
        onUpgrade: @escaping () -> Void
    ) {
        self._selectedLevel = selectedLevel
        self.isPro = isPro
        self.onConfirm = onConfirm
        self.onUpgrade = onUpgrade
        self._pendingLevel = State(initialValue: selectedLevel.wrappedValue)
    }

    private struct Tier: Identifiable {
        let id: Int
        let range: String
        let name: String
        let descriptor: String
        let isPro: Bool
    }

    private let tiers: [Tier] = [
        Tier(id: 1, range: "1·2",  name: "Starter",    descriptor: "Build the habit",     isPro: false),
        Tier(id: 3, range: "3·4",  name: "Developing", descriptor: "Finding your rhythm", isPro: false),
        Tier(id: 5, range: "5·6",  name: "Confident",  descriptor: "In the groove",       isPro: false),
        Tier(id: 7, range: "7·8",  name: "Advanced",   descriptor: "High stakes",         isPro: true),
        Tier(id: 9, range: "9·10", name: "Expert",     descriptor: "The edge",            isPro: true),
    ]

    private func bandId(for level: Int) -> Int {
        switch level {
        case 1...2: 1
        case 3...4: 3
        case 7...8: 7
        case 9...10: 9
        default: 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(AppColors.faint)
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 18)

            Text("Choose your difficulty.")
                .font(AppFonts.display(22))
                .foregroundStyle(AppColors.text)
                .padding(.bottom, 4)

            Text("Questions adapt to the band you pick.")
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(tiers) { tier in
                    let isSelected = bandId(for: pendingLevel) == tier.id
                    let locked = tier.isPro && !isPro

                    Button {
                        if locked {
                            onUpgrade()
                        } else {
                            pendingLevel = tier.id
                        }
                    } label: {
                        tierRow(tier: tier, selected: isSelected, locked: locked)
                    }
                    .buttonStyle(.plain)

                    if tier.id != tiers.last?.id {
                        Divider()
                            .overlay(AppColors.border)
                    }
                }
            }

            Button {
                onConfirm(pendingLevel)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm · Level \(pendingLevel)")
                        .font(AppFonts.bodyBold(14))
                        .foregroundStyle(AppColors.onGold)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(AppColors.gold)
                .clipShape(Capsule())
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(AppColors.bg)
    }

    private func tierRow(tier: Tier, selected: Bool, locked: Bool) -> some View {
        HStack(spacing: 14) {
            Text(tier.range)
                .font(AppFonts.body(12))
                .italic()
                .foregroundStyle(selected ? AppColors.gold : AppColors.dim)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.name)
                    .font(AppFonts.bodyBold(15))
                    .foregroundStyle(AppColors.text)
                Text(tier.descriptor)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.dim)
            }

            Spacer()

            if locked {
                Text("PRO")
                    .font(AppFonts.bodyBold(10))
                    .kerning(0.5)
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.gold.opacity(0.15))
                    .clipShape(Capsule())
            } else if selected {
                ZStack {
                    Circle()
                        .fill(AppColors.gold)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.onGold)
                }
            }
        }
        .padding(.vertical, 14)
        .opacity(locked ? 0.7 : 1)
        .contentShape(Rectangle())
    }
}
