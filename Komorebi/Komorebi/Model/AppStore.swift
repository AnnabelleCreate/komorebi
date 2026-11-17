import Foundation
import Observation
import WidgetKit

/// The single source of truth for everything Komorebi remembers.
/// Saved as JSON in Application Support, so it survives quitting and relaunching.
@Observable
final class AppStore {
    static let shared = AppStore()

    var state: AppState {
        didSet {
            guard state != oldValue else { return }
            scheduleSave()
            if state.settings != oldValue.settings { applySettings() }
            if state.evening != oldValue.evening || state.night != oldValue.night {
                PromptScheduler.shared.apply(evening: state.evening, night: state.night)
            }
            if state.evening != oldValue.evening || state.night != oldValue.night
                || state.lastStoryID != oldValue.lastStoryID || state.progress != oldValue.progress {
                publishWidgetSnapshot()
            }
        }
    }

    /// Set when the saved file couldn't be read and Komorebi started fresh (a backup is kept).
    var recoveredFromDamagedSave = false
    /// Set when saving fails (for example, the phone is out of space).
    var saveProblem: String?

    private var saveWork: DispatchWorkItem?
    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let folder = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        fileURL = folder.appendingPathComponent("komorebi-state.json")

        var loaded = AppState()
        var damaged = false
        if fm.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                loaded = try JSONDecoder.komorebi.decode(AppState.self, from: data)
            } catch {
                damaged = true
                let backup = folder.appendingPathComponent("komorebi-state-damaged-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.copyItem(at: fileURL, to: backup)
            }
        }
        state = loaded
        recoveredFromDamagedSave = damaged
        applySettings()
        publishWidgetSnapshot()
    }

    // MARK: Saving

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        do {
            let data = try JSONEncoder.komorebi.encode(state)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            saveProblem = nil
        } catch {
            saveProblem = "Komorebi couldn't save just now. Your phone may be low on space."
        }
    }

    /// Erases everything Komorebi has saved on this phone.
    func eraseEverything() {
        let fm = FileManager.default
        try? fm.removeItem(at: fileURL)
        GardenStorage.erase()
        state = AppState()
        saveNow()
        PromptScheduler.shared.apply(evening: state.evening, night: state.night)
    }

    // MARK: Side effects

    private func applySettings() {
        let s = state.settings
        SoundEngine.shared.configure(effects: s.gentleSounds, ambience: s.ambience, volume: Float(s.volume))
        Haptics.shared.isEnabled = s.haptics
    }

    func publishWidgetSnapshot() {
        let story = StoryLibrary.shared.story(state.lastStoryID)
        let snapshot = WidgetSnapshot(
            storyID: story?.id,
            storyTitle: story?.title,
            storyAuthor: story?.author,
            storyProgress: story.flatMap { state.progress[$0.id]?.fraction } ?? 0,
            eveningOn: state.evening.isOn,
            eveningAsWidget: state.evening.style == .widget,
            eveningMinutes: state.evening.startMinutes,
            eveningWeekdays: state.evening.activeWeekdays,
            nightOn: state.night.isOn,
            nightAsWidget: state.night.style == .widget,
            nightStartMinutes: state.night.startMinutes,
            nightEndMinutes: state.night.endMinutes,
            nightWeekdays: state.night.activeWeekdays
        )
        if snapshot != WidgetSnapshot.load() {
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Convenience

    func reduceMotion(system: Bool) -> Bool {
        switch state.settings.reduceMotion {
        case .followPhone: return system
        case .on: return true
        case .off: return false
        }
    }

    func isFavorite(_ key: String) -> Bool { state.favorites.contains(key) }

    func toggleFavorite(_ key: String) {
        if let i = state.favorites.firstIndex(of: key) { state.favorites.remove(at: i) } else { state.favorites.append(key) }
    }

    func saveProgress(storyID: String, blockIndex: Int, blockCount: Int) {
        let fraction = blockCount > 1 ? Double(blockIndex) / Double(blockCount - 1) : 1
        let previous = state.progress[storyID]
        let finished = (previous?.finished ?? false) || fraction >= 0.98
        state.progress[storyID] = ReadingProgress(blockIndex: blockIndex, fraction: min(1, fraction), finished: finished, updatedAt: Date())
        state.lastStoryID = storyID
    }

    func keep(line: String, from storyID: String) {
        guard !state.keptLines.contains(where: { $0.storyID == storyID && $0.text == line }) else { return }
        state.keptLines.insert(KeptLine(storyID: storyID, text: line, keptAt: Date()), at: 0)
    }

    func hasKept(line: String, from storyID: String) -> Bool {
        state.keptLines.contains { $0.storyID == storyID && $0.text == line }
    }
}

extension JSONEncoder {
    static var komorebi: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var komorebi: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
