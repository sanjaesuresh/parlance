import SwiftUI

/// Cold-start prompt offering to finish scoring a recording that was
/// interrupted by force-quit or crash. Driven by `ResumeCandidate`.
struct SessionRecoverySheet: View {
    let candidate: ResumeCandidate
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.gold)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text("Resume your last session?")
                    .font(AppFonts.display(22))
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)

                Text("Your recording was interrupted. We can finish scoring it now, or discard it.")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 10) {
                PrimaryButton(title: "Resume", action: onResume)
                SecondaryButton(title: "Discard", action: onDiscard)
            }
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}
