import SwiftUI
import SafariServices

struct FirstLaunchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var username = ""
    @State private var selectedAvatar = "\u{1F3A4}"
    @State private var showPrivacyPolicy = false

    private let avatars = ["\u{1F3A4}", "\u{1F9E0}", "\u{1F680}", "\u{1F4BC}", "\u{1F981}", "\u{1F525}", "\u{26A1}", "\u{1F3AF}", "\u{1F3C6}", "\u{1F4A1}", "\u{1F31F}", "\u{1F3AD}"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                // Title
                VStack(spacing: 12) {
                    Text("Parlance")
                        .font(AppFonts.display(36))
                        .foregroundStyle(AppColors.text)

                    Text("Your personal speech coach.")
                        .font(AppFonts.body(16))
                        .foregroundStyle(AppColors.sub)
                }

                Text("Practice interviews, pitches, and presentations in 3-minute sessions.")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Name
                setupField(label: "What should we call you?") {
                    TextField("Your name", text: $name)
                        .font(AppFonts.body(18))
                        .foregroundStyle(AppColors.text)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > AppConstants.maxNameLength {
                                name = String(newValue.prefix(AppConstants.maxNameLength))
                            }
                            if username.isEmpty || username == generateUsername(from: String(name.dropLast())) {
                                username = generateUsername(from: name)
                            }
                        }
                }

                // Username
                setupField(label: "Choose a username", hint: "Friends can find you with this username") {
                    TextField("username", text: $username)
                        .font(AppFonts.body(18))
                        .foregroundStyle(AppColors.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: username) { _, newValue in
                            let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue { username = filtered }
                            if username.count > 20 { username = String(username.prefix(20)) }
                        }
                }

                // Avatar
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
                                        .font(.system(size: 36))
                                        .frame(width: 56, height: 56)
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
                                .accessibilityHint(selectedAvatar == emoji ? "" : "Double-tap to select this avatar")
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Submit
                Button {
                    createUser()
                } label: {
                    Text("Let's go")
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(isValid ? AppColors.bg : AppColors.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValid ? AppColors.gold : AppColors.border)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid)
                .padding(.horizontal, 24)

                // Privacy
                VStack(spacing: 4) {
                    Text("Audio is processed on-device. Pro subscribers' audio is analyzed by our AI for emotion detection.")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Text("Privacy Policy")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                            .underline()
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: privacyPolicyURL)
        }
    }

    // MARK: - Helpers

    private func setupField<Content: View>(label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.bodyMedium(14))
                .foregroundStyle(AppColors.sub)

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
        .padding(.horizontal, 24)
    }

    private var privacyPolicyURL: URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlancePrivacyPolicyURL") as? String ?? "https://example.com/privacy"
        return URL(string: urlString) ?? URL(string: "https://example.com/privacy")!
    }

    private func createUser() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let finalUsername = username.isEmpty ? generateUsername(from: trimmedName) : username
        let _ = PersistenceService.shared.createUser(
            name: trimmedName,
            username: finalUsername,
            avatar: selectedAvatar
        )
    }

    private func generateUsername(from name: String) -> String {
        let base = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return String(base.prefix(15))
    }
}
