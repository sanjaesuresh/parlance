import SwiftUI
import SafariServices

struct FirstLaunchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var selectedAvatar = "🎤"
    @State private var showPrivacyPolicy = false

    private let avatars = ["🎤", "🧠", "🚀", "💼", "🦁", "🔥", "⚡", "🎯", "🏆", "💡", "🌟", "🎭"]

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Parlance")
                    .font(AppFonts.display(36))
                    .foregroundStyle(AppColors.text)

                Text("Your personal speech coach.")
                    .font(AppFonts.body(16))
                    .foregroundStyle(AppColors.sub)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.sub)

                TextField("Your name", text: $name)
                    .font(AppFonts.body(18))
                    .foregroundStyle(AppColors.text)
                    .padding(14)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .onChange(of: name) { _, newValue in
                        if newValue.count > AppConstants.maxNameLength {
                            name = String(newValue.prefix(AppConstants.maxNameLength))
                        }
                    }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Text("Pick your avatar")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.sub)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(avatars, id: \.self) { emoji in
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
                                .onTapGesture { selectedAvatar = emoji }
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
                    .padding(.vertical, 16)
                    .background(isValid ? AppColors.gold : AppColors.border)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValid)
            .padding(.horizontal, 24)

            Spacer()

            Button {
                showPrivacyPolicy = true
            } label: {
                Text("Your voice data stays private. Privacy Policy")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .underline()
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: privacyPolicyURL)
        }
    }

    private var privacyPolicyURL: URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlancePrivacyPolicyURL") as? String ?? "https://example.com/privacy"
        return URL(string: urlString) ?? URL(string: "https://example.com/privacy")!
    }

    private func createUser() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let _ = PersistenceService.shared.createUser(name: trimmedName, avatar: selectedAvatar)
    }
}
