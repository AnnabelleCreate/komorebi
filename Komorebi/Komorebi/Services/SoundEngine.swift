import AVFoundation

/// Soft interface sounds and ambient loops. All sounds are bundled with the app.
/// Effects respect the Ring/Silent switch; narration uses its own playback session.
final class SoundEngine {
    static let shared = SoundEngine()

    enum Effect: String, CaseIterable { case bell, chime, tap, page, fold, sweep }
    enum Loop: String, CaseIterable {
        case sand = "sand-loop", river = "river-loop", wind = "wind-loop"
    }

    private var effects: [Effect: AVAudioPlayer] = [:]
    private var loops: [Loop: AVAudioPlayer] = [:]
    private var loopTargets: [Loop: Float] = [:]
    private(set) var effectsOn = true
    private(set) var ambienceOn = true
    private(set) var masterVolume: Float = 0.7
    private var prepared = false

    private init() {}

    func prepare() {
        guard !prepared else { return }
        prepared = true
        useAmbientSession()
        for effect in Effect.allCases {
            if let url = StoryLibrary.bundledURL(effect.rawValue, ext: "m4a", folder: "sounds"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                effects[effect] = player
            }
        }
        for loop in Loop.allCases {
            if let url = StoryLibrary.bundledURL(loop.rawValue, ext: "caf", folder: "sounds"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.numberOfLoops = -1
                player.volume = 0
                player.prepareToPlay()
                loops[loop] = player
            }
        }
    }

    /// Effects mix with other audio and follow the Silent switch.
    func useAmbientSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func configure(effects: Bool, ambience: Bool, volume: Float) {
        effectsOn = effects
        ambienceOn = ambience
        masterVolume = max(0, min(1, volume))
        for (loop, player) in loops where player.isPlaying {
            let target = (ambienceOn || loop == .sand) ? (loopTargets[loop] ?? 0) * masterVolume : 0
            player.setVolume(target, fadeDuration: 0.3)
        }
    }

    func play(_ effect: Effect, volume: Float = 1) {
        guard effectsOn, let player = effects[effect] else { return }
        player.currentTime = 0
        player.volume = volume * masterVolume
        player.play()
    }

    /// Starts (or retunes) a loop. `level` is 0…1 before the master volume.
    func setLoop(_ loop: Loop, level: Float, fade: TimeInterval = 0.25) {
        guard let player = loops[loop] else { return }
        loopTargets[loop] = level
        let allowed = loop == .sand ? effectsOn : ambienceOn
        let target = allowed ? level * masterVolume : 0
        if target > 0.0001 && !player.isPlaying {
            player.volume = 0
            player.play()
        }
        player.setVolume(target, fadeDuration: fade)
    }

    func stopLoop(_ loop: Loop, fade: TimeInterval = 0.8) {
        guard let player = loops[loop], player.isPlaying else { return }
        loopTargets[loop] = 0
        player.setVolume(0, fadeDuration: fade)
        DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.05) { [weak player] in
            if let player, player.volume < 0.001 { player.pause() }
        }
    }

    func stopAllLoops() { Loop.allCases.forEach { stopLoop($0) } }
}
