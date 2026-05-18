import SwiftUI
import SwiftData
import PhotosUI

struct ProfileEditSheet: View {
    @Bindable var user: User
    let onDismiss: () -> Void

    @State private var name: String
    @State private var username: String
    @State private var location: String
    @State private var occupation: String
    @State private var selectedAvatar: String  // "__photo__" when a custom photo is active
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var pendingCropImage: UIImage?

    private struct CroppingImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private let avatars = [
        "\u{1F3A4}", "\u{1F9E0}", "\u{1F680}", "\u{1F4BC}", "\u{1F981}", "\u{1F525}",
        "\u{26A1}", "\u{1F3AF}", "\u{1F3C6}", "\u{1F4A1}", "\u{1F31F}", "\u{1F3AD}"
    ]

    init(user: User, onDismiss: @escaping () -> Void) {
        self.user = user
        self.onDismiss = onDismiss
        _name = State(initialValue: user.displayName)
        _username = State(initialValue: user.username ?? "")
        _location = State(initialValue: user.location ?? "")
        _occupation = State(initialValue: user.occupation ?? "")
        _selectedAvatar = State(initialValue: user.profileImageData != nil ? "__photo__" : user.avatarEmoji)
        _pickedImageData = State(initialValue: user.profileImageData)
    }

    @State private var profanityError: String?
    @State private var avatarErrorMessage: String?
    @State private var isSavingAvatar = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && username.count >= 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar picker
                    VStack(spacing: 12) {
                        Text("AVATAR")
                            .font(AppFonts.bodyBold(10))
                            .foregroundStyle(AppColors.dim)
                            .kerning(1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Photo picker — first item
                                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                                    let isSelected = selectedAvatar == "__photo__"
                                    ZStack {
                                        if isSelected, let data = pickedImageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 52, height: 52)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(isSelected ? AppColors.gold.opacity(0.2) : AppColors.card)
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "plus")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(isSelected ? AppColors.gold : AppColors.sub)
                                        }
                                    }
                                    .overlay(
                                        Circle().stroke(
                                            isSelected ? AppColors.gold : AppColors.border,
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                    )
                                    .frame(width: 52, height: 52)
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

                                // Emoji avatars
                                ForEach(avatars, id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 52, height: 52)
                                        .background(selectedAvatar == emoji ? AppColors.gold.opacity(0.2) : AppColors.card)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(
                                                selectedAvatar == emoji ? AppColors.gold : AppColors.border,
                                                lineWidth: selectedAvatar == emoji ? 2 : 1
                                            )
                                        )
                                        .onTapGesture { selectedAvatar = emoji }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.top, 8)

                    field(label: "Name") {
                        TextField("Your name", text: $name)
                            .font(AppFonts.body(16))
                            .foregroundStyle(AppColors.text)
                            .onChange(of: name) { _, newValue in
                                if newValue.count > AppConstants.maxNameLength {
                                    name = String(newValue.prefix(AppConstants.maxNameLength))
                                }
                            }
                    }

                    field(label: "Username", hint: "At least 3 characters. Letters, numbers, underscores.") {
                        TextField("username", text: $username)
                            .font(AppFonts.body(16))
                            .foregroundStyle(AppColors.text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: username) { _, newValue in
                                let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                if filtered != newValue { username = filtered }
                                if username.count > 20 { username = String(username.prefix(20)) }
                            }
                    }

                    field(label: "Location", hint: "Optional") {
                        TextField("City, Country", text: $location)
                            .font(AppFonts.body(16))
                            .foregroundStyle(AppColors.text)
                            .onChange(of: location) { _, newValue in
                                if newValue.count > 40 { location = String(newValue.prefix(40)) }
                            }
                    }

                    field(label: "Occupation", hint: "Optional") {
                        TextField("Your role or field", text: $occupation)
                            .font(AppFonts.body(16))
                            .foregroundStyle(AppColors.text)
                            .onChange(of: occupation) { _, newValue in
                                if newValue.count > 40 { occupation = String(newValue.prefix(40)) }
                            }
                    }
                    if let avatarErrorMessage {
                        Text(avatarErrorMessage)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppColors.bg)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(AppColors.sub)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(isValid && !isSavingAvatar ? AppColors.gold : AppColors.dim)
                        .disabled(!isValid || isSavingAvatar)
                }
            }
            .alert(
                "Content Not Allowed",
                isPresented: Binding(
                    get: { profanityError != nil },
                    set: { if !$0 { profanityError = nil } }
                ),
                presenting: profanityError
            ) { _ in
                Button("OK", role: .cancel) { profanityError = nil }
            } message: { msg in
                Text(msg)
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

    // MARK: - Helpers

    @ViewBuilder
    private func field<Content: View>(
        label: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(AppColors.dim)
                .kerning(1)

            content()
                .padding(14)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
                )

            if let hint {
                Text(hint)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedOccupation = occupation.trimmingCharacters(in: .whitespaces)

        // Profanity check before persisting
        let fieldsToCheck: [(String, String)] = [
            (trimmedName, "Name"),
            (username, "Username"),
            (trimmedLocation, "Location"),
            (trimmedOccupation, "Occupation")
        ]
        for (value, label) in fieldsToCheck {
            if let rejection = ProfanityFilter.validate(value, fieldName: label) {
                profanityError = rejection
                return
            }
        }

        user.displayName = trimmedName
        user.username = username
        user.location = trimmedLocation.isEmpty ? nil : trimmedLocation
        user.occupation = trimmedOccupation.isEmpty ? nil : trimmedOccupation

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
                await MainActor.run {
                    avatarErrorMessage = "Couldn't update photo. Try again."
                    isSavingAvatar = false
                }
            }
        }
    }
}
