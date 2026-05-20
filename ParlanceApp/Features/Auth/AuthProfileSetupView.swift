import SwiftUI
import Combine

struct AuthProfileSetupView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var username = ""
    @State private var occupation = ""
    @State private var location: String? = nil
    @State private var selectedAvatar = Self.avatars.randomElement()!
    @State private var comfortLevel = 0

    private enum Field: Hashable { case name, username, occupation }
    @FocusState private var focusedField: Field?

    private static let avatars = [
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        comfortLevel > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 4)

                VStack(spacing: 6) {
                    BouncingTitleView(text: "Set up your profile", fontSize: 30, animated: false)
                    Text("Takes 30 seconds.")
                        .font(AppFonts.body(15))
                        .foregroundStyle(AppColors.sub)
                }

                // Padding/background is applied inside each TextField's modifier
                // chain (before .accessibilityIdentifier) — matching the
                // emailField pattern in AuthView — so the accessibility element
                // resolves to the full padded card rather than the inner 22pt
                // text strip. setupField stays a pure label/hint wrapper.
                setupField(label: "What should we call you?") {
                    TextField("Your name", text: $name)
                        .font(AppFonts.body(17))
                        .foregroundStyle(AppColors.text)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .username }
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                        .accessibilityIdentifier("nameField")
                        .onChange(of: name) { _, newValue in
                            if newValue.count > AppConstants.maxNameLength {
                                name = String(newValue.prefix(AppConstants.maxNameLength))
                            }
                        }
                }

                // Username
                setupField(label: "Username", hint: "Friends can search for you by username") {
                    TextField("e.g. alexsmith", text: $username)
                        .font(AppFonts.body(17))
                        .foregroundStyle(AppColors.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .occupation }
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                        .accessibilityIdentifier("usernameField")
                        .onChange(of: username) { _, newValue in
                            let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue { username = filtered }
                            if username.count > 20 { username = String(username.prefix(20)) }
                        }
                }

                // Occupation (optional)
                setupField(label: "Job or role", hint: "Optional — helps tailor your practice") {
                    TextField("e.g. Software Engineer, Student…", text: $occupation)
                        .font(AppFonts.body(17))
                        .foregroundStyle(AppColors.text)
                        .focused($focusedField, equals: .occupation)
                        .submitLabel(.next)
                        .onSubmit { focusedField = nil }
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                }

                // Location (optional) — Apple Maps-backed city autocomplete
                LocationPickerField(
                    location: $location,
                    label: "Where are you based?",
                    hint: "Optional",
                    placeholder: "Search your city"
                )
                .padding(.horizontal, 24)

                // Comfort level
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How comfortable are you with public speaking?")
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.sub)
                        Text("Sets your starting difficulty — you can change this anytime.")
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.dim)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 8) {
                        ForEach(comfortOptions, id: \.level) { option in
                            Button {
                                comfortLevel = option.level
                            } label: {
                                HStack(spacing: 14) {
                                    Text(option.emoji)
                                        .font(.system(size: 26))
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
                            .accessibilityIdentifier("comfortOption_\(option.level)")
                            .padding(.horizontal, 24)
                        }
                    }
                }

                // Avatar
                VStack(spacing: 12) {
                    Text("Pick your avatar")
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Self.avatars, id: \.self) { emoji in
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
                        .padding(.vertical, 4)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                }

                let disabled = !isValid || viewModel.isLoading

                Button {
                    Task {
                        await viewModel.signUpWithProfile(
                            name: name,
                            username: username,
                            location: location,
                            occupation: occupation,
                            avatar: selectedAvatar,
                            comfortLevel: comfortLevel
                        )
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(AppColors.onGold)
                        } else {
                            Text("Let's go")
                                .font(AppFonts.bodyBold(18))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AppColors.onGold)
                    .background(disabled ? AppColors.gold.opacity(0.4) : AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(disabled)
                .accessibilityIdentifier("letsGoButton")
                .padding(.horizontal, 24)

                Text("AI feedback is for practice. Not professional coaching, therapy, or medical advice.")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 6) {
                    Link("Privacy Policy", destination: URL(string: "https://theparlance.app/privacy")!)
                    Text("·").foregroundStyle(AppColors.dim)
                    Link("Support", destination: URL(string: "https://theparlance.app/support")!)
                }
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.dim)
                .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(AppFonts.body(15))
                    }
                    .foregroundStyle(AppColors.sub)
                }
            }
        }
    }

    // MARK: - Helpers

    private func setupField<Content: View>(label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.bodyMedium(14))
                .foregroundStyle(AppColors.sub)

            content()

            if let hint {
                Text(hint)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
        }
        .padding(.horizontal, 24)
    }
}
