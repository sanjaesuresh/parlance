import SwiftUI
import SafariServices
import SwiftData

// Shown when an authenticated user has no local profile (e.g. signing in on a new device).
struct FirstLaunchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService

    @State private var name = ""
    @State private var username = ""
    @State private var occupation = ""
    @State private var location: String? = nil
    @State private var selectedAvatar = "\u{1F3A4}"
    @State private var comfortLevel = 0
    @State private var showPrivacyPolicy = false
    @State private var profanityError: String?

    private let avatars = [
        "\u{1F3A4}", "\u{1F9E0}", "\u{1F680}", "\u{1F4BC}", "\u{1F981}",
        "\u{1F525}", "\u{26A1}", "\u{1F3AF}", "\u{1F3C6}", "\u{1F4A1}",
        "\u{1F31F}", "\u{1F3AD}"
    ]

    private let comfortOptions: [(emoji: String, label: String, sublabel: String, level: Int)] = [
        ("😰", "Nervous", "Public speaking stresses me out", 1),
        ("🙂", "Getting there", "I've done it, but room to improve", 4),
        ("😎", "Confident", "I'm comfortable speaking in public", 7)
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && comfortLevel > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Set up your profile")
                            .font(AppFonts.display(30))
                            .foregroundStyle(AppColors.text)
                        Text(".")
                            .font(AppFonts.display(30))
                            .foregroundStyle(AppColors.gold)
                    }
                    Text("Takes 30 seconds.")
                        .font(AppFonts.body(15))
                        .foregroundStyle(AppColors.sub)
                }

                setupField(label: "What should we call you?") {
                    TextField("Your name", text: $name)
                        .font(AppFonts.body(17))
                        .foregroundStyle(AppColors.text)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > AppConstants.maxNameLength {
                                name = String(newValue.prefix(AppConstants.maxNameLength))
                            }
                        }
                }

                setupField(label: "Username", hint: "Friends can search for you by username") {
                    TextField("e.g. alexsmith", text: $username)
                        .font(AppFonts.body(17))
                        .foregroundStyle(AppColors.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: username) { _, newValue in
                            let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue { username = filtered }
                            if username.count > 20 { username = String(username.prefix(20)) }
                        }
                }

                setupField(label: "Job or role", hint: "Optional — helps tailor your practice") {
                    TextField("e.g. Software Engineer, Student…", text: $occupation)
                        .font(AppFonts.body(17))
                        .foregroundStyle(AppColors.text)
                }

                LocationPickerField(
                    location: $location,
                    label: "Where are you based?",
                    hint: "Optional — shown on leaderboards",
                    placeholder: "Search your city"
                )
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("How comfortable are you with public speaking?")
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.sub)
                        .padding(.horizontal, 24)

                    VStack(spacing: 8) {
                        ForEach(comfortOptions, id: \.level) { option in
                            Button {
                                comfortLevel = option.level
                            } label: {
                                HStack(spacing: 14) {
                                    Text(option.emoji).font(.system(size: 26))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.label)
                                            .font(AppFonts.bodyBold(14))
                                            .foregroundStyle(AppColors.text)
                                        Text(option.sublabel)
                                            .font(AppFonts.body(12))
                                            .foregroundStyle(AppColors.dim)
                                    }
                                    Spacer()
                                    if comfortLevel == option.level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppColors.gold)
                                            .font(.system(size: 18))
                                    }
                                }
                                .padding(14)
                                .background(comfortLevel == option.level ? AppColors.gold.opacity(0.1) : AppColors.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(comfortLevel == option.level ? AppColors.gold.opacity(0.6) : AppColors.border, lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                VStack(spacing: 12) {
                    Text("Pick your avatar")
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.sub)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(avatars, id: \.self) { emoji in
                                Button {
                                    selectedAvatar = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 34))
                                        .frame(width: 54, height: 54)
                                        .background(selectedAvatar == emoji ? AppColors.gold.opacity(0.2) : AppColors.card)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(
                                                selectedAvatar == emoji ? AppColors.gold : AppColors.border,
                                                lineWidth: selectedAvatar == emoji ? 2 : 1
                                            )
                                        )
                                }
                                .accessibilityLabel("\(emoji) avatar\(selectedAvatar == emoji ? ", selected" : "")")
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Button {
                    createUser()
                } label: {
                    Text("Let's go")
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(isValid ? AppColors.bg : AppColors.sub)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isValid ? AppColors.gold : AppColors.border)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid)
                .padding(.horizontal, 24)

                Text("AI feedback is for practice. Not professional coaching, therapy, or medical advice.")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Button { showPrivacyPolicy = true } label: {
                        Text("Privacy Policy")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                            .underline()
                    }
                    Button {
                        Task { try? await authService.signOut() }
                    } label: {
                        Text("Sign out")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.dim)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if let appleName = authService.pendingAppleDisplayName {
                name = appleName
                username = AuthViewModel.makeUsername(from: appleName)
                authService.pendingAppleDisplayName = nil
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: URL(string: "https://theparlance.app/privacy")!)
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

    private func setupField<Content: View>(label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.bodyMedium(14))
                .foregroundStyle(AppColors.sub)

            content()
                .padding(14)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

            if let hint {
                Text(hint)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
        }
        .padding(.horizontal, 24)
    }

    private func createUser() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalUsername = username.isEmpty ? AuthViewModel.makeUsername(from: trimmedName) : username
        let occ = occupation.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, comfortLevel > 0 else { return }

        // Profanity check before persisting
        let fieldsToCheck: [(String, String)] = [
            (trimmedName, "Name"),
            (finalUsername, "Username"),
            (occ, "Occupation")
        ]
        for (value, label) in fieldsToCheck {
            if let rejection = ProfanityFilter.validate(value, fieldName: label) {
                profanityError = rejection
                return
            }
        }

        let uid = authService.currentUserID ?? ""
        let trimmedLocation = location?.trimmingCharacters(in: .whitespaces)
        let user = PersistenceService.shared.createUser(
            supabaseUID: uid,
            name: trimmedName,
            username: finalUsername,
            location: (trimmedLocation?.isEmpty ?? true) ? nil : trimmedLocation,
            occupation: occ.isEmpty ? nil : occ,
            avatar: selectedAvatar,
            practiceLevel: comfortLevel
        )
        Task {
            do {
                try await SyncService.shared.createProfile(for: user, authService: authService)
            } catch {
                #if DEBUG
                print("[Setup] createProfile failed: \(error)")
                #endif
                // Silent fail here is acceptable — local user is created, profile will retry on next sync
            }
        }
    }
}
