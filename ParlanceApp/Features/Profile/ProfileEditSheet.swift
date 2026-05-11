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
                                        if let data = try? await item?.loadTransferable(type: Data.self) {
                                            pickedImageData = data
                                            selectedAvatar = "__photo__"
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
                        .foregroundStyle(isValid ? AppColors.gold : AppColors.dim)
                        .disabled(!isValid)
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

        if selectedAvatar == "__photo__" {
            user.profileImageData = pickedImageData
        } else {
            user.profileImageData = nil
            user.avatarEmoji = selectedAvatar
        }

        try? PersistenceService.shared.context.save()
        onDismiss()
    }
}
