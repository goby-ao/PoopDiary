import CoreHaptics
import UIKit

enum Haptics {
    private static var continuousEngine: CHHapticEngine?
    private static var continuousPlayer: CHHapticPatternPlayer?

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

    @discardableResult
    static func startFlushRumble() -> Bool {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.hapticsEnabled, defaultValue: true) else {
            return false
        }

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            play(.medium)
            return false
        }

        do {
            stopFlushRumble()

            let engine = try CHHapticEngine()
            engine.stoppedHandler = { _ in
                continuousPlayer = nil
                continuousEngine = nil
            }
            engine.resetHandler = {
                try? continuousEngine?.start()
            }
            try engine.start()

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.42),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28)
                ],
                relativeTime: 0,
                duration: 8
            )
            let pulse = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.72),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.34)
                ],
                relativeTime: 0.04
            )
            let pattern = try CHHapticPattern(events: [event, pulse], parameters: [])
            let player = try engine.makePlayer(with: pattern)

            try player.start(atTime: CHHapticTimeImmediate)
            continuousEngine = engine
            continuousPlayer = player
            return true
        } catch {
            play(.heavy)
            return false
        }
    }

    static func stopFlushRumble() {
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
        continuousEngine?.stop()
        continuousEngine = nil
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
