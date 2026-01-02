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

    @Published var ipadTime: Int {
        didSet {
            UserDefaults.standard.set(ipadTime, forKey: "ipadTime")
        }
    }

    @Published var readingTime: Int {
        didSet {
            UserDefaults.standard.set(readingTime, forKey: "readingTime")
        }
    }

    @Published var showerTime: Int {
        didSet {
            UserDefaults.standard.set(showerTime, forKey: "showerTime")
        }
    }

    @Published var homeworkTime: Int {
        didSet {
            UserDefaults.standard.set(homeworkTime, forKey: "homeworkTime")
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

    @Published var sessionHistory: [TimerSession] {
        didSet {
            if let encoded = try? JSONEncoder().encode(sessionHistory) {
                UserDefaults.standard.set(encoded, forKey: "sessionHistory")
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

        // Load session history
        if let data = UserDefaults.standard.data(forKey: "sessionHistory"),
           let decoded = try? JSONDecoder().decode([TimerSession].self, from: data) {
            self.sessionHistory = decoded
        } else {
            self.sessionHistory = []
        }
    }
}
