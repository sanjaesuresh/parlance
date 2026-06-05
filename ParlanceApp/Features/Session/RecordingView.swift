import SwiftUI

struct RecordingView: View {
    let question: Question
    let mode: SessionMode
    let level: Int
    @ObservedObject var recorder: AudioRecorder
    let permissionsService: PermissionsService
    var autoStart: Bool = false
    let onStop: () -> Void
    var onCancel: (() -> Void)?
    /// Called when the recorder stopped itself due to an AVAudioSession
    /// interruption (phone call, Siri, etc.). The parent should surface
    /// this explicitly instead of treating it as a normal stop.
    var onInterrupted: (() -> Void)?

    @StateObject private var viewModel = RecordingViewModel()
    @State private var showNudge = false
    @State private var didManualStop = false
    @State private var showCancelConfirmation = false
    @State private var didAutoStart = false
    @State private var recordingDotVisible = true
    @State private var startHaptic = false
    @State private var stopHaptic = false
    @State private var blockedStopFlash = false
    @State private var blockedHaptic = false

    private var targetProgress: Double {
        guard question.targetDuration > 0 else { return 0 }
        return min(1.0, recorder.elapsedTime / Double(question.targetDuration))
    }

    private var ringColor: Color {
        recorder.elapsedTime >= Double(question.targetDuration) ? AppColors.teal : AppColors.gold
    }

    var body: some View {
        VStack(spacing: 0) {
            SessionNavBar(
                leading: {
                    BackButton {
                        if recorder.isRecording {
                            showCancelConfirmation = true
                        } else {
                            recorder.deleteRecording()
                            onCancel?()
                        }
                    }
                },
                center: {
                    HStack(spacing: 7) {
                        PillBadge(text: mode.displayName, emoji: mode.emoji, color: mode.accentColor, small: true)
                        Text("Lv \(level)")
                            .font(AppFonts.bodyMedium(10))
                            .foregroundStyle(AppColors.sub)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(AppColors.card)
                            .clipShape(Capsule())
                    }
                },
                trailing: { EmptyView() }
            )

            ScrollView {
                VStack(spacing: 0) {
                    // Prompt card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 7) {
                            Text(DifficultyLevel.tier(for: level))
                                .font(AppFonts.bodyMedium(10))
                                .foregroundStyle(AppColors.dim)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(AppColors.faint)
                                .clipShape(Capsule())

                            PillBadge(text: "\(question.targetDuration)s", emoji: "⏱", color: mode.accentColor, small: true)
                        }

                        Text("\"\(question.question)\"")
                            .font(AppFonts.display(19))
                            .foregroundStyle(AppColors.text)
                            .lineSpacing(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 20, borderColor: mode.accentColor.opacity(0.3))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Focus areas
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(height: 1)
                            Text("Focus areas")
                                .font(AppFonts.bodyBold(9))
                                .foregroundStyle(AppColors.dim)
                                .kerning(0.4)
                                .fixedSize()
                            Rectangle()
                                .fill(AppColors.border)
                                .frame(height: 1)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(question.tips.enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.custom("Fraunces72pt-Bold", size: 18))
                                        .foregroundStyle(mode.accentColor)
                                        .frame(width: 16, alignment: .leading)
                                    Text(tip)
                                        .font(AppFonts.body(13))
                                        .foregroundStyle(AppColors.text.opacity(0.88))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    // Nudge
                    if showNudge {
                        HStack {
                            Text("💡 Stay deliberate. Don't rush to fill silence.")
                                .font(AppFonts.body(11))
                                .foregroundStyle(mode.accentColor)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(mode.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 16)
                        .transition(.opacity)
                    }

                    // Wrap-up warning
                    if recorder.shouldShowWrapUp {
                        Text("Wrapping up in \(Int(AppConstants.maxRecordingDuration - recorder.elapsedTime))s…")
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.red)
                            .padding(.top, 12)
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
                .font(AppFonts.display(54))
                .foregroundStyle(recorder.isRecording ? AppColors.gold : AppColors.faint)
                .padding(.top, 18)

            // Recording indicator
            if recorder.isRecording {
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppColors.gold)
                        .frame(width: 7, height: 7)
                        .opacity(recordingDotVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6), value: recordingDotVisible)
                    Text("RECORDING")
                        .font(AppFonts.bodyBold(11))
                        .foregroundStyle(AppColors.gold)
                }
                .opacity(0.8)
                .padding(.top, 4)
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        recordingDotVisible.toggle()
                    }
                }
            } else {
                Text("Tap mic when ready")
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
                    .padding(.top, 4)
            }

            // Mic button with target duration ring
            Button {
                if recorder.isRecording {
                    if recorder.canStop {
                        stopHaptic.toggle()
                        didManualStop = true
                        _ = recorder.stopRecording()
                        onStop()
                    } else {
                        blockedHaptic.toggle()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                            blockedStopFlash = true
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 700_000_000)
                            withAnimation(.easeOut(duration: 0.25)) {
                                blockedStopFlash = false
                            }
                        }
                    }
                } else {
                    startHaptic.toggle()
                    viewModel.handleRecordTap(recorder: recorder, permissions: permissionsService, targetDuration: TimeInterval(question.targetDuration))
                }
            } label: {
                ZStack {
                    // Background track
                    Circle()
                        .stroke(AppColors.border, lineWidth: 4)
                        .frame(width: 116, height: 116)

                    // Target duration progress ring
                    Circle()
                        .trim(from: 0, to: targetProgress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 116, height: 116)
                        .animation(.linear(duration: 0.25), value: targetProgress)

                    Circle()
                        .fill((recorder.isRecording ? AppColors.red : AppColors.gold).opacity(0.1))
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(recorder.isRecording ? AppColors.red : AppColors.gold)
                        .frame(width: 78, height: 78)

                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Text("🎤")
                            .font(.system(size: 26))
                    }
                }
            }
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
            .padding(.top, 12)

            Text("Target: \(question.targetDuration)s")
                .font(AppFonts.body(10))
                .foregroundStyle(AppColors.dim)
                .padding(.top, 6)

            Group {
                if recorder.isRecording && !recorder.canStop {
                    let remaining = Int(AppConstants.minRecordingDuration - recorder.elapsedTime) + 1
                    Text("Stop available in \(max(0, remaining))s")
                        .font(AppFonts.bodyMedium(blockedStopFlash ? 16 : 11))
                        .foregroundStyle(blockedStopFlash ? AppColors.red : AppColors.sub)
                        .scaleEffect(blockedStopFlash ? 1.08 : 1.0)
                } else if recorder.isRecording {
                    Text("Tap to finish & analyze")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                } else {
                    Text("Tap to start")
                        .font(AppFonts.body(11))
                        .foregroundStyle(AppColors.dim)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: startHaptic)
        .sensoryFeedback(.impact(weight: .light),  trigger: stopHaptic)
        .sensoryFeedback(.warning, trigger: blockedHaptic)
        .onAppear {
            if autoStart && !didAutoStart && !recorder.isRecording {
                didAutoStart = true
                viewModel.handleRecordTap(recorder: recorder, permissions: permissionsService, targetDuration: TimeInterval(question.targetDuration))
            }
        }
        .onChange(of: recorder.elapsedTime) { _, _ in
            showNudge = recorder.shouldShowNudge
        }
        .onChange(of: recorder.isRecording) { oldValue, newValue in
            // Auto-stop: recorder stopped itself without a manual tap. Distinguish:
            //   - .interruption (phone call, Siri) → surface explicitly via onInterrupted
            //     so the coordinator can show a "session was interrupted" state instead
            //     of silently auto-processing a partial clip
            //   - .maxDuration or any other → treat as a normal stop
            if oldValue && !newValue && !didManualStop {
                if recorder.stoppedReason == .interruption, let onInterrupted {
                    onInterrupted()
                } else {
                    onStop()
                }
            }
        }
        .alert("Microphone Access", isPresented: $viewModel.showMicPrePrompt) {
            Button("Continue") {
                Task { let _ = await viewModel.requestMicPermission(permissions: permissionsService) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Parlance records your voice on this device. The audio is deleted after the session. Only the transcript is sent to our AI for coaching feedback.")
        }
        .alert("Speech Recognition", isPresented: $viewModel.showSpeechPrePrompt) {
            Button("Enable") {
                Task { await viewModel.requestSpeechPermission(permissions: permissionsService) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Parlance transcribes what you say so the AI coach can give specific feedback. Apple's speech recognition may briefly send audio to Apple to produce the transcript.")
        }
        .alert("Speech Recognition Disabled", isPresented: $viewModel.showSpeechDenied) {
            Button("Open Settings") { permissionsService.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Parlance needs Speech Recognition to transcribe your sessions. Enable it in Settings → Privacy & Security → Speech Recognition.")
        }
        .alert("Permission Required", isPresented: $viewModel.showPermissionDenied) {
            Button("Open Settings") { permissionsService.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.permissionDeniedMessage)
        }
        .alert("Recording Failed", isPresented: $viewModel.recordingStartFailed) {
            Button("OK") {}
        } message: {
            Text("Could not start recording. Please check available storage and try again.")
        }
        .alert("End Session?", isPresented: $showCancelConfirmation) {
            Button("End", role: .destructive) {
                _ = recorder.stopRecording()
                recorder.deleteRecording()
                onCancel?()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your recording will be discarded.")
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
