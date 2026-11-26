// What you see when you open an app Pork is holding:
// - the unlock check: "Pork wants to hear from you" (write or take a photo);
// - during a focus session: the focus clock's screen (the iPhone version of
//   being sent back to Pork's page).

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        porkShield(name: application.localizedDisplayName ?? "This app", token: application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        porkShield(name: application.localizedDisplayName ?? "This app", token: application.token)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        porkShield(name: webDomain.domain ?? "This site", token: nil)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        porkShield(name: webDomain.domain ?? "This site", token: nil)
    }

    private let ink = UIColor(red: 0.18, green: 0.15, blue: 0.13, alpha: 1)
    private let muted = UIColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 1)
    private let wall = UIColor(red: 0.965, green: 0.906, blue: 0.812, alpha: 1)
    private let green = UIColor(red: 0.227, green: 0.553, blue: 0.361, alpha: 1)
    private let gold = UIColor(red: 0.773, green: 0.541, blue: 0.0, alpha: 1)
    private let red = UIColor(red: 0.851, green: 0.263, blue: 0.231, alpha: 1)

    private func shield(_ image: String, _ title: String, _ subtitle: String,
                        _ primary: String, _ color: UIColor, _ secondary: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: wall,
            icon: UIImage(named: image),
            title: ShieldConfiguration.Label(text: title, color: ink),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: muted),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: .white),
            primaryButtonBackgroundColor: color,
            secondaryButtonLabel: secondary.map { ShieldConfiguration.Label(text: $0, color: muted) })
    }

    private func porkShield(name: String, token: ApplicationToken?) -> ShieldConfiguration {
        var s = PorkStore.load()
        let now = Date()
        s.advance(now)

        // The focus clock comes first while it keeps this app closed.
        if ScreenTime.focusBlocks(token, s) {
            switch s.phase {
            case .focus where s.left(now) > 0:
                let mins = Int(ceil(s.left(now) / 60))
                return shield("PorkSleep", "Pork is napping 💤",
                              "\(name) isn't a focus app. Reach your focus goal first (\(mins) min to go). After that, opening it starts your break.",
                              "Back to focus", green, nil)
            case .focus:
                let n = s.earned(now)
                return shield("PorkSleep", "Focus goal reached! 🦴",
                              "Pork earned \(PorkClock.treatsText(n)). Start your break now and Pork gets his treats, or keep focusing for a bonus treat every \(s.settings.bonusEveryMin) min.",
                              "Start my break", gold, "Keep focusing")
            case .overtime:
                let late = s.lateBy(now)
                let pacing = late < paceSeconds
                return shield(pacing ? "PorkPace" : "PorkDoor",
                              pacing ? "Can we go out? 🥺" : "Woof! Let me out! 🐾",
                              "Your break is over (−\(PorkClock.text(late))). Pork is \(pacing ? "pacing by" : "scratching") the door. Let him out to end your break; the late time is added to your next focus.",
                              "🐾 End the fun — let Pork out", red, "Not now")
            default:
                break
            }
        }

        // The unlock check.
        let level = Gate.settings.level
        let tapped = Gate.startedAt.map { now.timeIntervalSince($0) < 10 * 60 } ?? false
        return shield("PorkWait", "Hi! Pork wants to hear from you 🐾",
                      DiaryLevel.ask(level) + " It goes in your diary, then \(name) opens."
                        + (tapped ? "\n\nTap the notification at the top of the screen to write." : ""),
                      tapped ? "✏️ Send the notification again" : "✏️ Write to Pork", green, "Not now")
    }
}
