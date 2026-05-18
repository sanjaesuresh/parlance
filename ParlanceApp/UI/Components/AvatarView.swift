// ParlanceApp/UI/Components/AvatarView.swift
import SwiftUI

/// Single render site for a user's avatar.
/// - `avatarUrl` + `avatarUpdatedAt` come from Supabase.
/// - `avatarEmoji` is always the fallback (placeholder + error case + nil URL).
/// - `localOverride` is used only for the current user's own avatar to render
///   instantly from cached bytes without waiting for AsyncImage.
struct AvatarView: View {
    let avatarUrl: String?
    let avatarEmoji: String
    let avatarUpdatedAt: Date?
    var localOverride: Data? = nil
    var size: CGFloat = 44
    var emojiFontSize: CGFloat = 24

    var body: some View {
        Group {
            if let data = localOverride, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty, .failure:
                        emojiFallback
                    case .success(let image):
                        image.resizable().scaledToFill()
                    @unknown default:
                        emojiFallback
                    }
                }
            } else {
                emojiFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var resolvedURL: URL? {
        guard let path = avatarUrl, !path.isEmpty else { return nil }
        return AvatarService.shared.publicURL(forPath: path, updatedAt: avatarUpdatedAt)
    }

    private var emojiFallback: some View {
        ZStack {
            Circle().fill(AppColors.card)
            Text(avatarEmoji).font(.system(size: emojiFontSize))
        }
    }
}
