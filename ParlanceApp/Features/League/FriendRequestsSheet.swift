import SwiftUI

struct FriendRequestsSheet: View {
    @ObservedObject var socialService: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var requestsWithProfiles: [FriendRequestWithProfile] = []
    @State private var isLoading = true
    @State private var inFlight: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var acceptHaptic = false
    @State private var declineHaptic = false

    var body: some View {
        NavigationStack {
            content
                .background(AppColors.bg)
                .navigationTitle("Friend Requests")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(AppFonts.bodyMedium(15))
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
        .sensoryFeedback(.success, trigger: acceptHaptic)
        .sensoryFeedback(.selection, trigger: declineHaptic)
        .alert(
            "Couldn't update request",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            skeletonList
        } else if requestsWithProfiles.isEmpty {
            emptyState
        } else {
            requestList
        }
    }

    private var skeletonList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in skeletonRow }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .allowsHitTesting(false)
    }

    private var skeletonRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.faint)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.faint)
                    .frame(width: 112, height: 13)
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.faint)
                    .frame(width: 74, height: 11)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.faint)
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(AppColors.faint)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(14)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: AppConstants.cardRadius).stroke(AppColors.border, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(AppColors.sub)
            Text("No pending requests")
                .font(AppFonts.bodyMedium(16))
                .foregroundStyle(AppColors.text)
            Text("When someone adds you, their request will appear here.")
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("friendRequestsEmptyState")
    }

    private var requestList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(requestsWithProfiles) { item in
                    requestRow(item: item)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func requestRow(item: FriendRequestWithProfile) -> some View {
        let profile = item.senderProfile
        let username = profile?.username ?? ""
        let displayName = profile?.displayName ?? "Unknown"
        let avatarEmoji = profile?.avatarEmoji ?? "👤"
        let occupation = profile?.occupation

        return HStack(spacing: 12) {
            Text(avatarEmoji)
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(AppColors.faint)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(AppFonts.bodyMedium(15))
                    .foregroundStyle(AppColors.text)
                Text("@\(username)")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)
                if let occ = occupation, !occ.isEmpty {
                    Text(occ)
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.dim)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    accept(item)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: AppConstants.IconButton.glyph, weight: .bold))
                        .foregroundStyle(AppColors.onGold)
                        .frame(
                            width: AppConstants.IconButton.size,
                            height: AppConstants.IconButton.size
                        )
                        .background(AppColors.gold)
                        .clipShape(Circle())
                        .frame(
                            width: AppConstants.IconButton.hitTarget,
                            height: AppConstants.IconButton.hitTarget
                        )
                        .contentShape(Rectangle())
                }
                .disabled(inFlight.contains(item.id))
                .accessibilityLabel("Accept")
                .accessibilityIdentifier("friendRequestAcceptButton_\(username)")

                Button {
                    decline(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: AppConstants.IconButton.glyph - 1, weight: .bold))
                        .foregroundStyle(AppColors.sub)
                        .frame(
                            width: AppConstants.IconButton.size,
                            height: AppConstants.IconButton.size
                        )
                        .background(AppColors.card2)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
                        .frame(
                            width: AppConstants.IconButton.hitTarget,
                            height: AppConstants.IconButton.hitTarget
                        )
                        .contentShape(Rectangle())
                }
                .disabled(inFlight.contains(item.id))
                .accessibilityLabel("Decline")
                .accessibilityIdentifier("friendRequestDeclineButton_\(username)")
            }
        }
        .padding(14)
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

    private func accept(_ item: FriendRequestWithProfile) {
        guard !inFlight.contains(item.id) else { return }
        inFlight.insert(item.id)
        acceptHaptic.toggle()
        Task {
            do {
                try await socialService.acceptRequest(
                    item.request.id,
                    fromUserId: item.request.fromUserId
                )
                withAnimation(.easeOut(duration: 0.22)) {
                    requestsWithProfiles.removeAll { $0.id == item.id }
                }
            } catch {
                errorMessage = "Couldn't accept the request. Please try again."
            }
            inFlight.remove(item.id)
        }
    }

    private func decline(_ item: FriendRequestWithProfile) {
        guard !inFlight.contains(item.id) else { return }
        inFlight.insert(item.id)
        declineHaptic.toggle()
        Task {
            do {
                try await socialService.declineRequest(item.request.id)
                withAnimation(.easeOut(duration: 0.22)) {
                    requestsWithProfiles.removeAll { $0.id == item.id }
                }
            } catch {
                errorMessage = "Couldn't decline the request. Please try again."
            }
            inFlight.remove(item.id)
        }
    }
}
