import AudioToolbox
import Foundation

enum AppPreferenceKey {
    static let soundEnabled = "soundEnabled"
    static let hapticsEnabled = "hapticsEnabled"
}

enum SoundEffect {
    case tap
    case poop
    case small
    case normal
    case large
    case sleep
    case flush
    case reward
    case achievement

    var systemSoundID: SystemSoundID {
        switch self {
        case .tap:
            return 1104
        case .poop:
            return 1057
        case .small:
            return 1103
        case .normal:
            return 1322
        case .large:
            return 1025
        case .sleep:
            return 1003
        case .flush:
            return 1025
        case .reward:
            return 1013
        case .achievement:
            return 1025
        }
    }
}

final class SoundManager {
    static let shared = SoundManager()

    private init() {}

    func play(_ effect: SoundEffect) {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.soundEnabled, defaultValue: true) else {
            return
        }

        // 系统内置短音效没有失败回调；这里保持无状态调用，避免音效不可用时影响主流程。
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }
}

enum HapticEffect {
    case light
    case medium
    case heavy
    case soft
    case success
}

enum InteractionFeedback {
    static func play(sound: SoundEffect, haptic: HapticEffect) {
        // 声音和震动在同一个交互入口同步触发，保证点击反馈感知一致。
        SoundManager.shared.play(sound)
        Haptics.play(haptic)
    }

    static func reward() {
        play(sound: .reward, haptic: .success)
    }

    static func mascotCombo() {
        play(sound: .poop, haptic: .heavy)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            play(sound: .small, haptic: .medium)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            play(sound: .poop, haptic: .medium)
        }
    }
}

extension UserDefaults {
    func optionalBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else { return defaultValue }
        return bool(forKey: key)
    }
}
