import Foundation

// After every change: refresh the Live Activity and the screen.
enum PorkHooks {
    static func changed(_ s: PorkState) {
        Task { await LiveActivities.update(s) }
        Task { @MainActor in AppModel.shared.reload() }
    }

    /// Wait for the Live Activity to be updated (for buttons that run while
    /// the app is in the background).
    static func settle(_ s: PorkState) async {
        await LiveActivities.update(s)
    }
}
