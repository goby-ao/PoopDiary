import UIKit

enum Haptics {
    static func play(_ effect: HapticEffect) {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.hapticsEnabled, defaultValue: true) else {
            return
        }

        switch effect {
        case .light:
            impact(.light)
        case .medium:
            impact(.medium)
        case .heavy:
            impact(.heavy)
        case .soft:
            impact(.soft)
        case .success:
            success()
        }
    }

    static func softTap() {
        play(.soft)
    }

    static func cheerfulTap() {
        play(.medium)
    }

    static func success() {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.hapticsEnabled, defaultValue: true) else {
            return
        }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
