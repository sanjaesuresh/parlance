// Parlance/Features/Auth/AuthView.swift
import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 60)

                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Parlance")
                            .font(AppFonts.display(42))
                            .foregroundStyle(AppColors.text)
                        KeyframeAnimator(initialValue: CGFloat(0), repeating: true) { offset in
                            Text(".")
                                .font(AppFonts.display(42))
                                .foregroundStyle(AppColors.gold)
                                .offset(y: offset)
                        } keyframes: { _ in
                            // Rest on ground
                            LinearKeyframe(0, duration: 0.45)
                            // Launch up — spring decelerates naturally like fighting gravity
                            SpringKeyframe(-13, duration: 0.26, spring: .init(duration: 0.26, bounce: 0))
                            // Fall — accelerate back down, slight overshoot at impact
                            CubicKeyframe(2.5, duration: 0.20)
                            // Settle
                            CubicKeyframe(0, duration: 0.09)
                        }
                    }
                    Text("Your AI speech coach.")
                        .font(AppFonts.body(16))
                        .foregroundStyle(AppColors.sub)
                }

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
                                }
                            } label: {
                                Text(isSignUp ? "Create account" : "Sign in")
                                    .font(viewModel.isSignUp == isSignUp
                                          ? AppFonts.bodyBold(14)
                                          : AppFonts.body(14))
                                    .foregroundStyle(viewModel.isSignUp == isSignUp
                                                     ? AppColors.text
                                                     : AppColors.dim)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        viewModel.isSignUp == isSignUp
                                            ? AppColors.card
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(4)
                    .background(AppColors.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .font(AppFonts.body(15))
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                    SecureField("Password", text: $viewModel.password)
                        .font(AppFonts.body(15))
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await viewModel.submitEmailAuth() }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                                    .font(AppFonts.bodyBold(16))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.black)
                        .background(AppColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.bg.ignoresSafeArea())
    }
}
