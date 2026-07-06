import AudioToolbox
import AVFoundation
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
    case gurgleLow
    case gurgleHigh
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
        case .gurgleLow:
            return 1101
        case .gurgleHigh:
            return 1103
        case .reward:
            return 1013
        case .achievement:
            return 1025
        }
    }
}

final class SoundManager {
    static let shared = SoundManager()

    private var gurgleEngine: AVAudioEngine?
    private var gurgleSourceNode: AVAudioSourceNode?
    private var gameMusicEngine: AVAudioEngine?
    private var gameMusicSourceNode: AVAudioSourceNode?
    private var oneShotEngines: [AVAudioEngine] = []
    private var oneShotPlayers: [AVAudioPlayerNode] = []

    private init() {}

    func play(_ effect: SoundEffect) {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.soundEnabled, defaultValue: true) else {
            return
        }

        // 系统内置短音效没有失败回调；这里保持无状态调用，避免音效不可用时影响主流程。
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }

    func playFlushGurglePulse(_ pulse: Int) {
        play(pulse.isMultiple(of: 2) ? .gurgleLow : .gurgleHigh)
    }

    @discardableResult
    func startFlushGurgle() -> Bool {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.soundEnabled, defaultValue: true) else {
            return false
        }

        if gurgleEngine?.isRunning == true {
            return true
        }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let engine = AVAudioEngine()
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            play(.gurgleLow)
            return false
        }

        let sourceNode = makeFlushGurgleSourceNode(sampleRate: sampleRate)
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.62
        engine.prepare()

        do {
            try engine.start()
            gurgleEngine = engine
            gurgleSourceNode = sourceNode
            return true
        } catch {
            engine.stop()
            play(.gurgleLow)
            return false
        }
    }

    func stopFlushGurgle() {
        guard let engine = gurgleEngine else { return }

        engine.stop()
        if let sourceNode = gurgleSourceNode {
            engine.detach(sourceNode)
        }
        gurgleSourceNode = nil
        gurgleEngine = nil
    }

    @discardableResult
    func startPoopStompMusic() -> Bool {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.soundEnabled, defaultValue: true) else {
            return false
        }

        if gameMusicEngine?.isRunning == true {
            return true
        }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let engine = AVAudioEngine()
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return false
        }

        let sourceNode = makePoopStompMusicSourceNode(sampleRate: sampleRate)
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.34
        engine.prepare()

        do {
            try engine.start()
            gameMusicEngine = engine
            gameMusicSourceNode = sourceNode
            return true
        } catch {
            engine.stop()
            return false
        }
    }

    func stopPoopStompMusic() {
        guard let engine = gameMusicEngine else { return }

        engine.stop()
        if let sourceNode = gameMusicSourceNode {
            engine.detach(sourceNode)
        }
        gameMusicSourceNode = nil
        gameMusicEngine = nil
    }

    func playMineWarning() {
        guard UserDefaults.standard.optionalBool(forKey: AppPreferenceKey.soundEnabled, defaultValue: true) else {
            return
        }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let sampleRate = 44_100.0
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = makeMineWarningBuffer(format: format, sampleRate: sampleRate)
        else {
            play(.large)
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.58
        engine.prepare()

        do {
            try engine.start()
            oneShotEngines.append(engine)
            oneShotPlayers.append(player)

            player.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak engine, weak player] in
                DispatchQueue.main.async {
                    player?.stop()
                    engine?.stop()

                    if let engine {
                        self?.oneShotEngines.removeAll { $0 === engine }
                    }

                    if let player {
                        self?.oneShotPlayers.removeAll { $0 === player }
                    }
                }
            }
            player.play()
        } catch {
            engine.stop()
            play(.large)
        }
    }

    private func makeFlushGurgleSourceNode(sampleRate: Double) -> AVAudioSourceNode {
        var lowPhase = 0.0
        var highPhase = 0.0
        var frameCursor = 0.0
        var noiseState: UInt64 = 0x9E37_79B9_7F4A_7C15
        let twoPi = Double.pi * 2

        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                let t = frameCursor / sampleRate
                frameCursor += 1

                let swirl = 0.5 + 0.5 * sin(t * twoPi * 2.15)
                let bubble = pow(max(0, sin(t * twoPi * 7.8 + sin(t * twoPi * 1.25))), 5)
                lowPhase += twoPi * (58 + 16 * swirl) / sampleRate
                highPhase += twoPi * (116 + 34 * bubble) / sampleRate

                noiseState = noiseState &* 2_862_933_555_777_941_757 &+ 3_037_000_493
                let noise = Double((noiseState >> 33) & 0xFFFF) / 32_768.0 - 1
                let water = sin(lowPhase) * 0.12 + sin(highPhase) * 0.065 + noise * 0.055 * (0.25 + bubble)
                let sample = Float(max(-0.38, min(0.38, water * (0.78 + 0.22 * swirl))))

                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = sample
                }
            }

            return noErr
        }
    }

    private func makePoopStompMusicSourceNode(sampleRate: Double) -> AVAudioSourceNode {
        var leadPhase = 0.0
        var bassPhase = 0.0
        var bellPhase = 0.0
        var frameCursor = 0.0
        let twoPi = Double.pi * 2
        let stepDuration = 60.0 / 136.0 / 2.0
        let leadNotes = [523.25, 659.25, 783.99, 659.25, 587.33, 739.99, 880.0, 739.99]
        let bassNotes = [261.63, 329.63, 392.0, 329.63]

        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                let t = frameCursor / sampleRate
                frameCursor += 1

                let step = Int(floor(t / stepDuration))
                let stepTime = t.truncatingRemainder(dividingBy: stepDuration)
                let attack = min(stepTime / 0.018, 1)
                let release = min((stepDuration - stepTime) / 0.075, 1)
                let envelope = max(0, min(attack, release))

                let leadFrequency = leadNotes[step % leadNotes.count]
                let bassFrequency = bassNotes[(step / 2) % bassNotes.count]
                let bellFrequency = leadNotes[(step + 2) % leadNotes.count] * 2

                leadPhase += twoPi * leadFrequency / sampleRate
                bassPhase += twoPi * bassFrequency / sampleRate
                bellPhase += twoPi * bellFrequency / sampleRate
                if leadPhase > twoPi { leadPhase -= twoPi }
                if bassPhase > twoPi { bassPhase -= twoPi }
                if bellPhase > twoPi { bellPhase -= twoPi }

                let lead = (sin(leadPhase) + 0.28 * sin(leadPhase * 2)) * 0.092 * envelope
                let bassPulse = step.isMultiple(of: 2) ? 1.0 : 0.55
                let bass = sin(bassPhase) * 0.045 * bassPulse
                let bell = max(0, sin(bellPhase)) * 0.030 * envelope
                let bounce = sin(t * twoPi * 2.0) * 0.014
                let sample = Float(max(-0.32, min(0.32, lead + bass + bell + bounce)))

                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = sample
                }
            }

            return noErr
        }
    }

    private func makeMineWarningBuffer(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer? {
        let duration = 0.42
        let totalFrames = AVAudioFrameCount(sampleRate * duration)
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames),
            let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = totalFrames

        var lowPhase = 0.0
        var highPhase = 0.0
        let twoPi = Double.pi * 2
        let frameCount = Int(totalFrames)

        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let progress = min(t / duration, 1)
            let attack = min(t / 0.018, 1)
            let release = min((duration - t) / 0.13, 1)
            let envelope = max(0, min(attack, release))
            let gate = sin(t * twoPi * 13) > 0 ? 1.0 : 0.32
            let lowFrequency = 620 - 430 * progress + sin(t * twoPi * 18) * 24
            let highFrequency = 980 + sin(t * twoPi * 24) * 120

            lowPhase += twoPi * lowFrequency / sampleRate
            highPhase += twoPi * highFrequency / sampleRate

            let low = sin(lowPhase) * 0.25
            let high = sin(highPhase) * 0.075
            let buzz = sin(lowPhase * 2.03) * 0.055
            let sample = (low + high + buzz) * gate * envelope
            channel[frame] = Float(max(-0.46, min(0.46, sample)))
        }

        return buffer
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
