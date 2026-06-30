import SwiftUI
import SwiftData
import UserNotifications

@main
struct RenewalsApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Subscription.self])
    }
}
