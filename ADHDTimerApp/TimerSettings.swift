import SwiftUI

// Session record for history tracking
struct TimerSession: Codable, Identifiable {
    let id: UUID
    let activity: String
    let activityIcon: String
    let allocatedTime: Int  // Original timer duration (seconds)
    let actualTime: Int     // How long they actually took (seconds)
    let completedAt: Date

    // Computed properties for time tracking
    var finishedEarly: Bool {
        actualTime < allocatedTime
    }

    var timeSaved: Int {
        max(0, allocatedTime - actualTime)
    }

    // Legacy support: duration returns allocatedTime for backwards compatibility
    var duration: Int {
        allocatedTime
    }

    init(activity: String, activityIcon: String, allocatedTime: Int, actualTime: Int) {
        self.id = UUID()
        self.activity = activity
        self.activityIcon = activityIcon
        self.allocatedTime = allocatedTime
        self.actualTime = actualTime
        self.completedAt = Date()
    }

    // Legacy initializer for backwards compatibility with old data
    init(activity: String, activityIcon: String, duration: Int) {
        self.init(activity: activity, activityIcon: activityIcon, allocatedTime: duration, actualTime: duration)
    }
}

@MainActor
class TimerSettings: ObservableObject {
    static let shared = TimerSettings()

    // iCloud Key-Value Storage for syncing across devices
    private let iCloud = NSUbiquitousKeyValueStore.default

    @Published var ipadTime: Int {
        didSet {
            UserDefaults.standard.set(ipadTime, forKey: "ipadTime")
            syncToiCloud(key: "ipadTime", value: ipadTime)
        }
    }

    @Published var readingTime: Int {
        didSet {
            UserDefaults.standard.set(readingTime, forKey: "readingTime")
            syncToiCloud(key: "readingTime", value: readingTime)
        }
    }

    @Published var showerTime: Int {
        didSet {
            UserDefaults.standard.set(showerTime, forKey: "showerTime")
            syncToiCloud(key: "showerTime", value: showerTime)
        }
    }

    @Published var homeworkTime: Int {
        didSet {
            UserDefaults.standard.set(homeworkTime, forKey: "homeworkTime")
            syncToiCloud(key: "homeworkTime", value: homeworkTime)
        }
    }

    // New settings for ADHD features
    @Published var tickSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(tickSoundEnabled, forKey: "tickSoundEnabled")
        }
    }

    // Child's name for personalization
    @Published var childName: String {
        didSet {
            UserDefaults.standard.set(childName, forKey: "childName")
            syncToiCloud(key: "childName", value: childName)
        }
    }

    // Check if onboarding has been completed
    var hasCompletedOnboarding: Bool {
        !childName.isEmpty
    }

    // Parent verification PIN
    @Published var parentPIN: String? {
        didSet {
            if let pin = parentPIN {
                UserDefaults.standard.set(pin, forKey: "parentPIN")
            } else {
                UserDefaults.standard.removeObject(forKey: "parentPIN")
            }
        }
    }

    var isVerificationEnabled: Bool {
        return parentPIN != nil && !parentPIN!.isEmpty
    }

    // Skip PIN setup permanently (user chose "Don't ask again")
    @Published var skipPINSetupPermanently: Bool {
        didSet {
            UserDefaults.standard.set(skipPINSetupPermanently, forKey: "skipPINSetupPermanently")
        }
    }

    // Stars reward system
    @Published var totalStars: Int {
        didSet {
            UserDefaults.standard.set(totalStars, forKey: "totalStars")
            syncToiCloud(key: "totalStars", value: totalStars)
        }
    }

    // Tutorial tracking
    @Published var hasSeenClockBadgeTip: Bool {
        didSet { UserDefaults.standard.set(hasSeenClockBadgeTip, forKey: "hasSeenClockBadgeTip") }
    }

    @Published var hasSeenStarsTip: Bool {
        didSet { UserDefaults.standard.set(hasSeenStarsTip, forKey: "hasSeenStarsTip") }
    }

    @Published var hasSeenHistoryTip: Bool {
        didSet { UserDefaults.standard.set(hasSeenHistoryTip, forKey: "hasSeenHistoryTip") }
    }

    @Published var hasSeenDoneButtonTip: Bool {
        didSet { UserDefaults.standard.set(hasSeenDoneButtonTip, forKey: "hasSeenDoneButtonTip") }
    }

    // Reset all tutorial flags (for replay)
    func resetTutorials() {
        hasSeenClockBadgeTip = false
        hasSeenStarsTip = false
        hasSeenHistoryTip = false
        hasSeenDoneButtonTip = false
    }

    // Streak multiplier for bonus stars
    var streakMultiplier: Double {
        if currentStreak >= 7 { return 2.0 }
        if currentStreak >= 3 { return 1.5 }
        return 1.0
    }

    // Award stars with streak multiplier applied
    func awardStars(baseAmount: Int) -> Int {
        let total = Int(Double(baseAmount) * streakMultiplier)
        totalStars += total
        return total
    }

    @Published var sessionHistory: [TimerSession] {
        didSet {
            if let encoded = try? JSONEncoder().encode(sessionHistory) {
                UserDefaults.standard.set(encoded, forKey: "sessionHistory")
                iCloud.set(encoded, forKey: "sessionHistory")
                iCloud.synchronize()
            }
        }
    }

    // Computed properties for streaks
    var todaySessionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessionHistory.filter { calendar.startOfDay(for: $0.completedAt) == today }.count
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let hasSession = sessionHistory.contains { calendar.startOfDay(for: $0.completedAt) == checkDate }
            if hasSession {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    func addSession(activity: String, activityIcon: String, allocatedTime: Int, actualTime: Int) {
        let session = TimerSession(activity: activity, activityIcon: activityIcon, allocatedTime: allocatedTime, actualTime: actualTime)
        sessionHistory.insert(session, at: 0)
        // Keep only last 100 sessions
        if sessionHistory.count > 100 {
            sessionHistory = Array(sessionHistory.prefix(100))
        }
    }

    // Legacy support: duration-only version (assumes used full time)
    func addSession(activity: String, activityIcon: String, duration: Int) {
        addSession(activity: activity, activityIcon: activityIcon, allocatedTime: duration, actualTime: duration)
    }

    private init() {
        self.ipadTime = UserDefaults.standard.object(forKey: "ipadTime") as? Int ?? 30
        self.readingTime = UserDefaults.standard.object(forKey: "readingTime") as? Int ?? 20
        self.showerTime = UserDefaults.standard.object(forKey: "showerTime") as? Int ?? 10
        self.homeworkTime = UserDefaults.standard.object(forKey: "homeworkTime") as? Int ?? 15
        self.tickSoundEnabled = UserDefaults.standard.object(forKey: "tickSoundEnabled") as? Bool ?? false
        self.childName = UserDefaults.standard.string(forKey: "childName") ?? ""
        self.parentPIN = UserDefaults.standard.string(forKey: "parentPIN")
        self.skipPINSetupPermanently = UserDefaults.standard.bool(forKey: "skipPINSetupPermanently")
        self.totalStars = UserDefaults.standard.integer(forKey: "totalStars")

        // Tutorial tracking
        self.hasSeenClockBadgeTip = UserDefaults.standard.bool(forKey: "hasSeenClockBadgeTip")
        self.hasSeenStarsTip = UserDefaults.standard.bool(forKey: "hasSeenStarsTip")
        self.hasSeenHistoryTip = UserDefaults.standard.bool(forKey: "hasSeenHistoryTip")
        self.hasSeenDoneButtonTip = UserDefaults.standard.bool(forKey: "hasSeenDoneButtonTip")

        // Load session history
        if let data = UserDefaults.standard.data(forKey: "sessionHistory"),
           let decoded = try? JSONDecoder().decode([TimerSession].self, from: data) {
            self.sessionHistory = decoded
        } else {
            self.sessionHistory = []
        }

        // Set up iCloud sync listener
        setupiCloudSync()
    }

    // MARK: - iCloud Sync

    private func setupiCloudSync() {
        // Listen for changes from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleiCloudChange(notification)
            }
        }
        // Trigger initial sync
        iCloud.synchronize()
    }

    private func syncToiCloud(key: String, value: Any) {
        iCloud.set(value, forKey: key)
        iCloud.synchronize()
    }

    private func handleiCloudChange(_ notification: Notification) {
        // Get the keys that changed
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        for key in changedKeys {
            switch key {
            case "ipadTime":
                if let value = iCloud.object(forKey: key) as? Int, value != ipadTime {
                    ipadTime = value
                }
            case "readingTime":
                if let value = iCloud.object(forKey: key) as? Int, value != readingTime {
                    readingTime = value
                }
            case "showerTime":
                if let value = iCloud.object(forKey: key) as? Int, value != showerTime {
                    showerTime = value
                }
            case "homeworkTime":
                if let value = iCloud.object(forKey: key) as? Int, value != homeworkTime {
                    homeworkTime = value
                }
            case "childName":
                if let value = iCloud.object(forKey: key) as? String, value != childName {
                    childName = value
                }
            case "totalStars":
                if let value = iCloud.object(forKey: key) as? Int, value != totalStars {
                    totalStars = value
                }
            case "sessionHistory":
                if let data = iCloud.object(forKey: key) as? Data {
                    mergeSessionHistory(from: data)
                }
            default:
                break
            }
        }
    }

    private func mergeSessionHistory(from iCloudData: Data) {
        guard let iCloudSessions = try? JSONDecoder().decode([TimerSession].self, from: iCloudData) else {
            return
        }

        // Merge: combine both, remove duplicates by ID, sort by date, keep 100
        var merged = sessionHistory
        for session in iCloudSessions {
            if !merged.contains(where: { $0.id == session.id }) {
                merged.append(session)
            }
        }
        merged.sort { $0.completedAt > $1.completedAt }

        // Only update if there are actual changes to avoid infinite loops
        let newHistory = Array(merged.prefix(100))
        if newHistory.count != sessionHistory.count ||
           !newHistory.elementsEqual(sessionHistory, by: { $0.id == $1.id }) {
            sessionHistory = newHistory
        }
    }
}
