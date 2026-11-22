import AVFoundation
import Combine
import MediaPlayer
import Observation
import UIKit

/// Plays the bundled LibriVox narrations, with a sleep timer that fades out gently,
/// Lock Screen controls, and a Live Activity.
@Observable
final class NarrationPlayer {
    static let shared = NarrationPlayer()

    enum SleepTimer: String, CaseIterable, Identifiable {
        case off, five, fifteen, thirty, endOfStory
        var id: String { rawValue }
        var label: String {
            switch self {
            case .off: return "Off"
            case .five: return "5 min"
            case .fifteen: return "15 min"
            case .thirty: return "30 min"
            case .endOfStory: return "End of story"
            }
        }
        var seconds: Double? {
            switch self {
            case .five: return 5 * 60
            case .fifteen: return 15 * 60
            case .thirty: return 30 * 60
            default: return nil
            }
        }
    }

    private(set) var story: Story?
    private(set) var isPlaying = false
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    private(set) var problem: String?
    /// False until the narration file is open and ready to play.
    private(set) var isReady = false
    private(set) var sleepTimer: SleepTimer = .off
    private(set) var sleepEndsAt: Date?
    /// Shown after the sleep timer fades a story out.
    var askStillAwake = false
    var rate: Float = 1.0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables: Set<AnyCancellable> = []
    private var fadeTimer: Timer?
    private var lastSavedSecond = -1

    private init() {
        configureRemoteCommands()
        ListeningControl.handler = { [weak self] action in
            guard let self else { return }
            switch action {
            case "add15": self.addTime(minutes: 15)
            case "stop": self.pause(); LiveActivityManager.shared.end()
            default: self.toggle()
            }
        }
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleInterruption(note)
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            self?.pause()
        }
    }

    var progress: Double { duration > 0 ? elapsed / duration : 0 }

    // MARK: Loading

    func load(_ story: Story) {
        if self.story?.id == story.id, player != nil { return }
        stop(keepStory: false)
        self.story = story
        problem = nil
        isReady = false
        guard let url = StoryLibrary.shared.audioURL(for: story) else {
            problem = "This narration isn’t in this build. You can still read the story."
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        self.player = player
        duration = story.audioSeconds

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .failed {
                    self.problem = "This narration couldn’t be played. You can still read the story."
                    self.isPlaying = false
                } else if status == .readyToPlay {
                    let seconds = item.duration.seconds
                    if seconds.isFinite && seconds > 0 { self.duration = seconds }
                    self.isReady = true
                    self.updateNowPlaying()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.finished() }
            .store(in: &cancellables)

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.tick(time.seconds)
        }

        let saved = AppStore.shared.state.audioPositions[story.id] ?? 0
        if saved > 5 && saved < story.audioSeconds - 10 {
            player.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
            elapsed = saved
        } else {
            elapsed = 0
        }
    }

    // MARK: Transport

    func play() {
        guard let player, problem == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
        if duration > 0 && elapsed >= duration - 1 { seek(to: 0) }
        player.volume = 1
        player.playImmediately(atRate: rate)
        isPlaying = true
        askStillAwake = false
        if let story {
            AppStore.shared.state.lastStoryID = story.id
            AppStore.shared.state.lastListenedID = story.id
        }
        updateNowPlaying()
        LiveActivityManager.shared.startOrUpdate(story: story, state: liveState)
    }

    func pause() {
        guard let player else { return }
        player.pause()
        isPlaying = false
        savePosition()
        updateNowPlaying()
        LiveActivityManager.shared.startOrUpdate(story: story, state: liveState)
    }

    func toggle() { isPlaying ? pause() : play() }

    func skip(by seconds: Double) { seek(to: elapsed + seconds) }

    func seek(to seconds: Double) {
        let target = max(0, min(duration > 0 ? duration - 0.5 : seconds, seconds))
        elapsed = target
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying { player?.rate = newRate }
        updateNowPlaying()
    }

    /// Stops playback and ends the Live Activity.
    func stop(keepStory: Bool = true) {
        savePosition()
        fadeTimer?.invalidate()
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        cancellables.removeAll()
        player?.pause()
        player = nil
        isPlaying = false
        sleepTimer = .off
        sleepEndsAt = nil
        if !keepStory { story = nil }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        LiveActivityManager.shared.end()
        SoundEngine.shared.useAmbientSession()
    }

    // MARK: Sleep timer

    func setSleepTimer(_ timer: SleepTimer) {
        sleepTimer = timer
        if let seconds = timer.seconds {
            sleepEndsAt = Date().addingTimeInterval(seconds)
        } else if timer == .endOfStory, duration > 0 {
            sleepEndsAt = Date().addingTimeInterval(max(0, (duration - elapsed) / Double(rate)))
        } else {
            sleepEndsAt = nil
        }
        LiveActivityManager.shared.startOrUpdate(story: story, state: liveState)
    }

    private func tick(_ seconds: Double) {
        guard seconds.isFinite else { return }
        elapsed = seconds
        if Int(seconds) / 10 != lastSavedSecond / 10 {
            lastSavedSecond = Int(seconds)
            savePosition()
        }
        if let end = sleepEndsAt, isPlaying, fadeTimer == nil, Date() >= end.addingTimeInterval(-8), sleepTimer != .endOfStory {
            fadeOut()
        }
    }

    /// Lowers the voice over eight seconds instead of cutting it off.
    private func fadeOut() {
        guard let player else { return }
        let start = Date()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            let t = Date().timeIntervalSince(start) / 8
            player.volume = Float(max(0, 1 - t))
            if t >= 1 {
                timer.invalidate()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.fadeTimer = nil
                    self.pause()
                    player.volume = 1
                    self.sleepTimer = .off
                    self.sleepEndsAt = nil
                    self.askStillAwake = true
                }
            }
        }
    }

    /// "Still awake? Add time": pushes the fade-out later.
    func addTime(minutes: Double) {
        let base = max(Date(), sleepEndsAt ?? Date())
        sleepEndsAt = base.addingTimeInterval(minutes * 60)
        if sleepTimer == .off || sleepTimer == .endOfStory { sleepTimer = .thirty }
        Haptics.shared.selection()
        LiveActivityManager.shared.startOrUpdate(story: story, state: liveState)
    }

    func addFifteenMinutes() {
        askStillAwake = false
        setSleepTimer(.fifteen)
        play()
    }

    private func finished() {
        isPlaying = false
        if let story { AppStore.shared.state.audioPositions[story.id] = 0 }
        sleepTimer = .off
        sleepEndsAt = nil
        updateNowPlaying()
        LiveActivityManager.shared.end()
    }

    private func savePosition() {
        guard let story else { return }
        AppStore.shared.state.audioPositions[story.id] = elapsed
    }

    private var liveState: ListeningAttributes.ContentState {
        ListeningAttributes.ContentState(isPlaying: isPlaying, sleepEndsAt: sleepEndsAt, elapsed: elapsed, duration: duration,
                                         playStartedAt: isPlaying ? Date().addingTimeInterval(-elapsed / Double(max(rate, 0.1))) : nil)
    }

    // MARK: Interruptions & Lock Screen

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            isPlaying = false
            savePosition()
        } else if let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
            play()
        }
    }

    private func configureRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        c.skipForwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipForwardCommand.addTarget { [weak self] _ in self?.skip(by: 15); return .success }
        c.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(by: -15); return .success }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let story else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: story.title,
            MPMediaItemPropertyArtist: story.author,
            MPMediaItemPropertyAlbumTitle: "Komorebi · \(story.source)",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
        ]
        if let image = UIImage(named: story.coverImageName) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
