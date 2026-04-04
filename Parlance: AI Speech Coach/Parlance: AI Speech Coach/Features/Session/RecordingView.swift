import SwiftUI

struct RecordingView: View {
    let question: Question
    let mode: SessionMode
    let level: Int
    @ObservedObject var recorder: AudioRecorder
    let permissionsService: PermissionsService
    let onStop: () -> Void

    @StateObject private var viewModel = RecordingViewModel()
    @State private var showNudge = false
    @State private var didAutoStop = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Prompt card
                    VStack(spacing: 12) {
                        Text(question.question)
                            .font(AppFonts.display(22))
                            .foregroundStyle(AppColors.text)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            PillBadge(text: "~\(question.targetDuration)s", color: mode.accentColor)
                            PillBadge(text: DifficultyLevel.name(for: level), color: AppColors.sub)
                        }
                    }
                    .padding(20)

                    // Coaching tips
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(question.tips.enumerated()), id: \.offset) { index, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(AppFonts.bodyMedium(14))
                                    .foregroundStyle(mode.accentColor)
                                Text(tip)
                                    .font(AppFonts.body(14))
                                    .foregroundStyle(AppColors.sub)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Nudge
                    if showNudge {
                        Text("Stay deliberate — don't rush to fill silence")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.gold.opacity(0.8))
                            .transition(.opacity)
                    }

                    // Wrap-up warning
                    if recorder.shouldShowWrapUp {
                        Text("Wrapping up in \(Int(AppConstants.maxRecordingDuration - recorder.elapsedTime))s…")
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.red)
                    }
                }
            }

            Spacer()

            // Waveform
            AnimatedWaveformView(
                levels: recorder.audioLevels,
                isActive: recorder.isRecording,
                accentColor: mode.accentColor
            )
            .padding(.horizontal, 24)

            // Timer
            Text(formatTime(recorder.elapsedTime))
                .font(AppFonts.display(48))
                .foregroundStyle(recorder.isRecording ? AppColors.gold : AppColors.sub.opacity(0.5))
                .padding(.top, 12)

            // Mic button
            Button {
                if recorder.isRecording && recorder.canStop {
                    let _ = recorder.stopRecording()
                    onStop()
                } else if !recorder.isRecording {
                    viewModel.handleRecordTap(recorder: recorder, permissions: permissionsService)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? AppColors.red : AppColors.gold)
                        .frame(width: 72, height: 72)

                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.bg)
                    }
                }
            }
            .disabled(recorder.isRecording && !recorder.canStop)
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .onChange(of: recorder.elapsedTime) { _, _ in
            showNudge = recorder.shouldShowNudge
        }
        .onChange(of: recorder.isRecording) { oldValue, newValue in
            // Detect auto-stop (was recording, now stopped, and we didn't trigger it)
            if oldValue && !newValue && !didAutoStop {
                didAutoStop = true
                onStop()
            }
        }
        // Permission pre-prompts
        .alert("Microphone Access", isPresented: $viewModel.showMicPrePrompt) {
            Button("Continue") {
                Task { let _ = await viewModel.requestMicPermission(permissions: permissionsService) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Parlance needs your microphone to record your practice sessions. Your audio is processed on-device.")
        }
        .alert("Speech Recognition", isPresented: $viewModel.showSpeechPrePrompt) {
            Button("Enable") {
                Task { await viewModel.requestSpeechPermission(permissions: permissionsService) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To analyze your speech, Parlance uses on-device transcription. Your transcript is never stored beyond your session.")
        }
        .alert("Permission Required", isPresented: $viewModel.showPermissionDenied) {
            Button("Open Settings") { permissionsService.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.permissionDeniedMessage)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
