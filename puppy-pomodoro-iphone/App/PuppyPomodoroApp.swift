// Puppy Pomodoro for iPhone: Pork's reminders, your time in each app, and
// Pork's diary (the unlock check).

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
                    if url.host == "dump" { model.showDump = true }
                    if url.host == "write" {
                        Gate.noteStart()
                        model.showWrite = true
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.becameActive()
                Task { await TodoStore.shared.refresh() }
            }
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

    // Show Pork's messages even while the app is open (not the "tap to write" one).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier == "pork.write" {
            completionHandler([])
            Task { @MainActor in AppModel.shared.checkGate() }
            return
        }
        completionHandler([.banner, .sound, .list])
    }

    // "Take a break" / "Let Pork out" buttons, and "Tap here to write to Pork".
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let s: PorkState
        switch response.actionIdentifier {
        case Alerts.takeBreakAction: s = PorkCommands.run(.takeBreak)
        case Alerts.letOutAction: s = PorkCommands.run(.release)
        default: s = PorkCommands.run(.sync)
        }
        if response.notification.request.content.userInfo["open"] as? String == "write" {
            Gate.noteStart()
            Task { @MainActor in AppModel.shared.showWrite = true }
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
