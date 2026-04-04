import SwiftUI
struct SessionCoordinator: View {
    let state: ActiveSessionState
    let onDismiss: () -> Void
    var body: some View { Text("Session").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
