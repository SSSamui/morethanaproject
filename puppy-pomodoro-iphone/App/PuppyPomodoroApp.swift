// Puppy Pomodoro for iPhone — a focus clock with Pork.

import SwiftUI
import UserNotifications

@main
struct PuppyPomodoroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in
                    if url.host == "hi" { model.showHi = true }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Alerts.registerCategories()
        Self.shareScratchSound()
        return true
    }

    // Show Pork's messages even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // "Take a break" / "Let Pork out" buttons on the notifications.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let s: PorkState
        switch response.actionIdentifier {
        case Alerts.takeBreakAction: s = PorkCommands.run(.takeBreak)
        case Alerts.letOutAction: s = PorkCommands.run(.release)
        default: s = PorkCommands.run(.sync)
        }
        Task {
            await LiveActivities.update(s)
            completionHandler()
        }
    }

    /// Notifications planned by the Screen Time extensions look for the
    /// scratching sound in the shared folder.
    private static func shareScratchSound() {
        guard let src = Bundle.main.url(forResource: "scratch", withExtension: "wav"),
              let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PorkStore.groupID)
        else { return }
        let dir = group.appendingPathComponent("Library/Sounds", isDirectory: true)
        let dst = dir.appendingPathComponent("scratch.wav")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: dst.path) {
            try? FileManager.default.copyItem(at: src, to: dst)
        }
    }
}
