// Reminders while you're on distraction apps, run by Shortcuts automations
// (an iPhone app can't see which app you open by itself):
// - you open a distraction app → after 5 min a Pork reminder, after 10 min
//   your to-dos (both times can be changed in Settings);
// - you open a focus app → those reminders are cancelled;
// - an event in Calendar right now → Pork's check-in opens with it.
// Also counts how often you opened distraction apps today.

import Foundation
import Photos
import UIKit
import UserNotifications

enum Nudges {
    static let porkID = "pork.nudge.pork"
    static let notesID = "pork.nudge.notes"
    static let category = "pork.nudge"

    private static var defaults: UserDefaults { PorkStore.defaults }

    /// How many times you opened a distraction app today.
    static var opensToday: Int {
        defaults.string(forKey: "distractDay") == dayKey() ? defaults.integer(forKey: "distractOpens") : 0
    }

    /// A distraction app was opened. Returns true when Pork's check-in should
    /// open right away (there's a calendar event now that wasn't shown yet).
    static func distractionOpened(now: Date = Date()) async -> Bool {
        let st = PorkStore.load().settings
        // count it
        if defaults.string(forKey: "distractDay") != dayKey(now) {
            defaults.set(dayKey(now), forKey: "distractDay")
            defaults.set(0, forKey: "distractOpens")
        }
        defaults.set(defaults.integer(forKey: "distractOpens") + 1, forKey: "distractOpens")
        guard st.hiEnabled else { return false }

        // Start the 5 / 10 minute reminders, unless they're already waiting.
        let started = defaults.object(forKey: "distractSince") as? Date
        let running = started.map { now.timeIntervalSince($0) < TimeInterval(st.notesMin * 60) } ?? false
        if !running {
            defaults.set(now, forKey: "distractSince")
            await schedule(st, from: now)
        }

        // An event in Calendar now: show it once (again after 30 min).
        guard let event = Todos.currentEvent(now: now), !event.allDay else { return false }
        let shownTitle = defaults.string(forKey: "eventShown")
        let shownAt = defaults.object(forKey: "eventShownAt") as? Date ?? .distantPast
        if shownTitle == event.title && now.timeIntervalSince(shownAt) < 30 * 60 { return false }
        defaults.set(event.title, forKey: "eventShown")
        defaults.set(now, forKey: "eventShownAt")
        return true
    }

    /// A focus app was opened: no reminders needed.
    static func focusOpened() {
        defaults.removeObject(forKey: "distractSince")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [porkID, notesID])
    }

    /// For the 12 am / 6 pm automations: true when to-dos are left, and Pork
    /// sends a reminder listing them.
    static func todosLeft(app: String?) async -> Bool {
        let st = PorkStore.load().settings
        let left = await Todos.unfinished(st)
        guard !left.isEmpty else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Finish your to-dos 🐾" + (app.map { " · opening \($0)" } ?? "")
        content.body = bullets(left.map(\.title))
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["open": "checkin"]
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "pork.todosLeft", content: content, trigger: nil))
        return true
    }

    private static func schedule(_ st: PorkSettings, from now: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [porkID, notesID])

        let pork = UNMutableNotificationContent()
        pork.title = "Pork misses you 🐾"
        pork.body = "\(st.nudgeMin) minutes on distractions. Put the phone down and come back to your to-dos?"
        pork.sound = .default
        pork.categoryIdentifier = category
        pork.userInfo = ["open": "checkin"]
        if let picture = await porkPicture(st) { pork.attachments = [picture] }
        try? await center.add(UNNotificationRequest(
            identifier: porkID, content: pork,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(st.nudgeMin * 60), repeats: false)))

        let todos = await Todos.load(st, now: now)
        let notes = UNMutableNotificationContent()
        notes.title = "\(st.notesMin) min on distractions · \(opensToday)× today 📝"
        notes.body = todos.preview.isEmpty
            ? "Tap to see your to-dos and screen time with Pork."
            : "To do:\n" + bullets(todos.preview)
        notes.sound = .default
        notes.categoryIdentifier = category
        notes.userInfo = ["open": "checkin"]
        try? await center.add(UNNotificationRequest(
            identifier: notesID, content: notes,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(st.notesMin * 60), repeats: false)))
    }

    /// A random photo of Pork from the album (or his drawing) for the reminder.
    private static func porkPicture(_ st: PorkSettings) async -> UNNotificationAttachment? {
        final class Box { var image: UIImage? }
        let box = Box()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "title = %@", st.hiAlbum)
            if let album = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).firstObject {
                let photoOptions = PHFetchOptions()
                photoOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                let assets = PHAsset.fetchAssets(in: album, options: photoOptions)
                if assets.count > 0 {
                    let asset = assets.object(at: Int.random(in: 0..<assets.count))
                    let request = PHImageRequestOptions()
                    request.isSynchronous = true
                    request.deliveryMode = .highQualityFormat
                    request.isNetworkAccessAllowed = true
                    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 900, height: 900),
                                                          contentMode: .aspectFit, options: request) { result, _ in
                        box.image = result
                    }
                }
            }
        }
        let image = box.image ?? UIImage(named: "PorkPace")
        guard let data = image?.jpegData(compressionQuality: 0.85) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "pork", url: url)
    }

    private static func bullets(_ titles: [String]) -> String {
        titles.map { "• " + $0 }.joined(separator: "\n")
    }

    private static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
