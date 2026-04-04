import SwiftUI
struct HomeView: View {
    let onStartSession: (ActiveSessionState) -> Void
    var body: some View { Text("Home").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
