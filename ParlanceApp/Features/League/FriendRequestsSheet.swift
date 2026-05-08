import SwiftUI

struct FriendRequestsSheet: View {
    @ObservedObject var socialService: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var requestsWithProfiles: [FriendRequestWithProfile] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requestsWithProfiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.sub)
                        Text("No pending requests")
                            .font(AppFonts.body(15))
                            .foregroundStyle(AppColors.sub)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("friendRequestsEmptyState")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(requestsWithProfiles) { item in
                                requestRow(item: item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(AppColors.bg)
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.gold)
                        .accessibilityIdentifier("friendRequestsDoneButton")
                }
            }
            .toolbarBackground(AppColors.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            requestsWithProfiles = await socialService.fetchPendingRequestsWithProfiles()
            isLoading = false
        }
    }

    private func requestRow(item: FriendRequestWithProfile) -> some View {
        let username = item.senderProfile?.username ?? ""

        return HStack(spacing: 12) {
            Text(item.senderProfile?.avatarEmoji ?? "\u{1F464}")
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background(AppColors.faint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.senderProfile?.displayName ?? "Unknown")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)
                Text("@\(username)")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Accept") {
                    Task {
                        try? await socialService.acceptRequest(
                            item.request.id,
                            fromUserId: item.request.fromUserId
                        )
                        requestsWithProfiles.removeAll { $0.id == item.id }
                    }
                }
                .font(AppFonts.bodyBold(13))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppColors.gold)
                .clipShape(Capsule())
                .accessibilityIdentifier("friendRequestAcceptButton_\(username)")

                Button("Decline") {
                    Task {
                        try? await socialService.declineRequest(item.request.id)
                        requestsWithProfiles.removeAll { $0.id == item.id }
                    }
                }
                .font(AppFonts.body(13))
                .foregroundStyle(AppColors.sub)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppColors.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
                .accessibilityIdentifier("friendRequestDeclineButton_\(username)")
            }
        }
        .padding(12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.border, lineWidth: 1)
        )
        // Expose child buttons as their own accessibility elements while still
        // keeping a row-level identifier — without this, the parent identifier
        // overrides each child and XCUITest can't find the inner buttons.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("friendRequestRow_\(username)")
    }
}
