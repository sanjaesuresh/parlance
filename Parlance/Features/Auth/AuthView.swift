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
                    Text("Parlance.")
                        .font(AppFonts.display(42))
                        .foregroundStyle(AppColors.text)
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
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Rectangle().fill(AppColors.border).frame(height: 1)
                    Text("or").font(AppFonts.body(13)).foregroundStyle(AppColors.dim).padding(.horizontal, 8)
                    Rectangle().fill(AppColors.border).frame(height: 1)
                }

                VStack(spacing: 12) {
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

                    Button {
                        withAnimation { viewModel.isSignUp.toggle() }
                        viewModel.errorMessage = nil
                    } label: {
                        Text(viewModel.isSignUp
                            ? "Already have an account? Sign in"
                            : "New here? Create an account")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.bg.ignoresSafeArea())
    }
}
