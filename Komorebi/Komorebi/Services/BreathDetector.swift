import AVFoundation
import Observation

/// Listens for one slow breath out (blowing toward the microphone) to release the lantern.
/// Only the loudness level is read; no audio is recorded or saved (it is written to /dev/null).
@Observable
final class BreathDetector {
    enum Status: Equatable { case idle, asking, listening, denied, unavailable }

    private(set) var status: Status = .idle
    /// 0…1, how strongly the person is blowing right now.
    private(set) var level: Double = 0
    /// 0…1, how much of the breath has been "used up" toward releasing the lantern.
    private(set) var progress: Double = 0
    var onComplete: (() -> Void)?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var floorDB: Float = -60
    private var samples = 0

    func start() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            begin()
        case .undetermined:
            status = .asking
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { self.begin() } else { self.status = .denied }
                }
            }
        case .denied:
            status = .denied
        @unknown default:
            status = .unavailable
        }
    }

    private func begin() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else { throw NSError(domain: "Komorebi", code: 1) }
            self.recorder = recorder
            status = .listening
            progress = 0
            samples = 0
            floorDB = -60
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.sample()
            }
        } catch {
            status = .unavailable
            stop()
        }
    }

    private func sample() {
        guard let recorder else { return }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        samples += 1
        // Learn the room's quiet level for the first half second.
        if samples < 10 { floorDB = max(floorDB, db); return }
        let above = db - max(floorDB, -55)
        let blowing = above > 16 && db > -32
        level = max(0, min(1, Double(above) / 30))
        if blowing {
            progress = min(1, progress + 0.05 * 0.45)
            if Int(progress * 20) != Int((progress - 0.0225) * 20) { Haptics.shared.grain(0.3) }
            if progress >= 1 {
                let done = onComplete
                stop()
                done?()
            }
        } else {
            progress = max(0, progress - 0.004)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        if status == .listening { status = .idle }
        level = 0
        SoundEngine.shared.useAmbientSession()
    }
}
