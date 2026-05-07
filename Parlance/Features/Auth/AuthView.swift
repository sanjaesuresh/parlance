import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel
    @State private var path = NavigationPath()

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack(path: $path) {
            authScreen
                .navigationDestination(for: String.self) { _ in
                    AuthProfileSetupView(viewModel: viewModel)
                }
        }
    }

    // MARK: - Auth screen

    private var authScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 60)

                bouncingTitle("Parlance")
                Text("Your AI speech coach.")
                    .font(AppFonts.body(16))
                    .foregroundStyle(AppColors.sub)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = viewModel.prepareAppleSignIn()
                } onCompletion: { result in
                    Task { await viewModel.handleAppleCompletion(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(maxWidth: 375, minHeight: 50, maxHeight: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Rectangle().fill(AppColors.border).frame(height: 1)
                    Text("or").font(AppFonts.body(13)).foregroundStyle(AppColors.dim).padding(.horizontal, 8)
                    Rectangle().fill(AppColors.border).frame(height: 1)
                }

                VStack(spacing: 12) {
                    // Sign in / Create account toggle
                    HStack(spacing: 0) {
                        ForEach([false, true], id: \.self) { isSignUp in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.isSignUp = isSignUp
                                    viewModel.errorMessage = nil
                                    viewModel.resetEmailSent = false
                                }
                            } label: {
                                Text(isSignUp ? "Create account" : "Sign in")
                                    .font(viewModel.isSignUp == isSignUp ? AppFonts.bodyBold(14) : AppFonts.body(14))
                                    .foregroundStyle(viewModel.isSignUp == isSignUp ? AppColors.text : AppColors.dim)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(viewModel.isSignUp == isSignUp ? AppColors.card : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(4)
                    .background(AppColors.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                    let emailInvalid = !viewModel.email.isEmpty && !viewModel.isValidEmail

                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .font(AppFonts.body(15))
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(emailInvalid ? AppColors.red : AppColors.border, lineWidth: 1))

                    if emailInvalid {
                        Text("Enter a valid email address.")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    let passwordTooShort = viewModel.isSignUp && !viewModel.password.isEmpty && !viewModel.isPasswordLongEnough

                    SecureField("Password", text: $viewModel.password)
                        .font(AppFonts.body(15))
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(passwordTooShort ? AppColors.red : AppColors.border, lineWidth: 1))

                    if passwordTooShort {
                        Text("Password must be at least \(AuthViewModel.minPasswordLength) characters.")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !viewModel.isSignUp {
                        HStack {
                            Spacer()
                            Button {
                                Task { await viewModel.sendPasswordReset() }
                            } label: {
                                Text("Forgot password?")
                                    .font(AppFonts.body(12))
                                    .foregroundStyle(AppColors.sub)
                            }
                        }
                    }

                    if viewModel.resetEmailSent {
                        Text("Password reset email sent. Check your inbox.")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    let disabled = !viewModel.canSubmit || viewModel.isLoading

                    Button {
                        if viewModel.isSignUp {
                            path.append("profile")
                        } else {
                            Task { await viewModel.submitSignIn() }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text(viewModel.isSignUp ? "Continue" : "Sign In")
                                    .font(AppFonts.bodyBold(16))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.black)
                        .background(disabled ? AppColors.gold.opacity(0.4) : AppColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(disabled)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Shared

    @ViewBuilder
    func bouncingTitle(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(text)
                .font(AppFonts.display(42))
                .foregroundStyle(AppColors.text)
            KeyframeAnimator(initialValue: CGFloat(0), repeating: true) { offset in
                Text(".")
                    .font(AppFonts.display(42))
                    .foregroundStyle(AppColors.gold)
                    .offset(y: offset)
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.45)
                SpringKeyframe(-13, duration: 0.26, spring: .init(duration: 0.26, bounce: 0))
                CubicKeyframe(2.5, duration: 0.20)
                CubicKeyframe(0, duration: 0.09)
            }
        }
    }
}
