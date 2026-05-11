import SwiftUI
import Combine
import UserNotifications

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var dailyReminderEnabled = false
    @Published var soundEffectsEnabled = true
    @Published var showResetConfirmation = false

    func loadSettings() {
        dailyReminderEnabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        soundEffectsEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
    }

    func toggleDailyReminder(_ enabled: Bool) {
        dailyReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dailyReminderEnabled")
        Task { await SyncService.shared.syncDailyReminderEnabled(enabled) }

        if enabled {
            requestNotificationPermission()
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    func toggleSoundEffects(_ enabled: Bool) {
        soundEffectsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "soundEffectsEnabled")
    }

    func resetAllData() {
        PersistenceService.shared.resetAllData()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                if granted {
                    self.scheduleDailyReminder()
                } else {
                    self.dailyReminderEnabled = false
                    UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                }
            }
        }
    }

    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Parlance"
        content.body = "Your daily challenge is waiting"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().add(request)
    }
}
