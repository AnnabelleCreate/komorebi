import UIKit

/// Light, sparse haptics. Turned off entirely by Settings → Haptics.
final class Haptics {
    static let shared = Haptics()
    var isEnabled = true

    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()
    private let select = UISelectionFeedbackGenerator()

    private init() {}

    func grain(_ intensity: CGFloat = 0.35) {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: intensity)
    }

    func tap() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.6)
    }

    func selection() {
        guard isEnabled else { return }
        select.selectionChanged()
    }

    func success() {
        guard isEnabled else { return }
        notify.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notify.notificationOccurred(.warning)
    }
}
