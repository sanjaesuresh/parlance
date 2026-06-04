import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AvatarPickerSheet: View {
    @Bindable var user: User
    let onDismiss: () -> Void

    @State private var selectedAvatar: String
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var pendingCropImage: UIImage?
    @State private var avatarErrorMessage: String?
    @State private var isSavingAvatar = false

    private let avatars = [
        "\u{1F3A4}", "\u{1F9E0}", "\u{1F680}", "\u{1F4BC}", "\u{1F981}", "\u{1F525}",
        "\u{26A1}", "\u{1F3AF}", "\u{1F3C6}", "\u{1F4A1}", "\u{1F31F}", "\u{1F3AD}"
    ]

    private let gridColumns = [
        GridItem(.adaptive(minimum: 60, maximum: 76), spacing: 14)
    ]

    init(user: User, onDismiss: @escaping () -> Void) {
        self.user = user
        self.onDismiss = onDismiss
        _selectedAvatar = State(initialValue: user.profileImageData != nil ? "__photo__" : user.avatarEmoji)
        _pickedImageData = State(initialValue: user.profileImageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    previewSection
                    photoSection
                    emojiSection
                    if let avatarErrorMessage {
                        Text(avatarErrorMessage)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(AppColors.sub)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(isSavingAvatar ? AppColors.dim : AppColors.gold)
                        .fontWeight(.semibold)
                        .disabled(isSavingAvatar)
                }
            }
            .onChange(of: photoPickerItem) { _, item in
                Task {
                    guard let item else { return }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        pendingCropImage = uiImage
                    }
                }
            }
            .sheet(item: Binding(
                get: { pendingCropImage.map { CroppingImage(image: $0) } },
                set: { newValue in
                    if newValue == nil { pendingCropImage = nil }
                }
            )) { wrapper in
                ImageCropSheet(
                    image: wrapper.image,
                    onSave: { data in
                        pickedImageData = data
                        selectedAvatar = "__photo__"
                        pendingCropImage = nil
                    },
                    onCancel: { pendingCropImage = nil }
                )
            }
        }
    }

    private struct CroppingImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    // MARK: - Preview

    private var previewSection: some View {
        HStack {
            Spacer()
            ZStack {
                if selectedAvatar == "__photo__",
                   let data = pickedImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColors.gold.opacity(0.5), lineWidth: 2))
                } else {
                    Circle()
                        .fill(AppColors.gold.opacity(0.2))
                        .frame(width: 96, height: 96)
                        .overlay(Circle().stroke(AppColors.gold.opacity(0.5), lineWidth: 2))
                        .overlay(Text(selectedAvatar).font(.system(size: 44)))
                }
            }
            Spacer()
        }
    }

    // MARK: - Photo section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(AppFonts.bodyBold(10))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .frame(width: 38, height: 38)
                        .background(AppColors.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pickedImageData == nil ? "Choose a photo" : "Replace photo")
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.text)
                        Text("Crop and position before saving")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.dim)
                }
                .padding(14)
                .background(AppColors.card2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Emoji grid

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emoji")
                .font(AppFonts.bodyBold(10))
                .kerning(0.4)
                .foregroundStyle(AppColors.dim)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(avatars, id: \.self) { emoji in
                    let isSelected = selectedAvatar == emoji
                    Button {
                        selectedAvatar = emoji
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .background(isSelected ? AppColors.gold.opacity(0.2) : AppColors.card2)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(
                                    isSelected ? AppColors.gold : AppColors.border,
                                    lineWidth: isSelected ? 2 : 1
                                )
                            )
                    }
                    .accessibilityLabel("\(emoji) avatar\(isSelected ? ", selected" : "")")
                }
            }
        }
    }

    private func save() {
        let isPhotoMode = (selectedAvatar == "__photo__")
        let photoDataChanged = isPhotoMode && pickedImageData != user.profileImageData
        let switchedToPhoto  = isPhotoMode && user.avatarUrl == nil
        let switchedToEmoji  = !isPhotoMode && (user.profileImageData != nil || user.avatarUrl != nil)
        let uid = user.supabaseUID

        isSavingAvatar = true
        avatarErrorMessage = nil
        Task {
            do {
                if isPhotoMode {
                    if (photoDataChanged || switchedToPhoto), let data = pickedImageData {
                        let path = try await AvatarService.shared.uploadAvatar(originalData: data, userId: uid)
                        let stamp = try await AvatarService.shared.updateProfileAvatar(userId: uid, path: path)
                        await MainActor.run {
                            user.profileImageData = data
                            user.avatarUrl = path
                            user.avatarUpdatedAt = stamp
                        }
                    }
                } else if switchedToEmoji {
                    try await AvatarService.shared.deleteAvatar(userId: uid)
                    let stamp = try await AvatarService.shared.updateProfileAvatar(userId: uid, path: nil)
                    await MainActor.run {
                        user.profileImageData = nil
                        user.avatarUrl = nil
                        user.avatarUpdatedAt = stamp
                        user.avatarEmoji = selectedAvatar
                    }
                } else {
                    await MainActor.run {
                        user.avatarEmoji = selectedAvatar
                    }
                }
                await MainActor.run {
                    try? PersistenceService.shared.context.save()
                    isSavingAvatar = false
                    onDismiss()
                }
            } catch {
                print("[AvatarUpload] failed: \(error)")
                await MainActor.run {
                    avatarErrorMessage = "Couldn't update photo: \(error.localizedDescription)"
                    isSavingAvatar = false
                }
            }
        }
    }
}
