import SwiftUI
import Combine

enum MilestoneType: Equatable {
    case halfway
    case fiveMinutes
    case twoMinutes
    case oneMinute
    case thirtySeconds
    case custom(String)
}

@MainActor
class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var totalTime: Int = 0
    @Published var isRunning: Bool = false
    @Published var showCustomPicker: Bool = false

    // New ADHD-friendly features
    @Published var currentActivity: String = ""
    @Published var currentActivityIcon: String = ""
    @Published var pausedAt: Date? = nil
    @Published var currentMilestone: MilestoneType? = nil
    @Published var milestoneMessage: String = ""

    // Parent verification
    @Published var awaitingVerification: Bool = false
    @Published var isVerified: Bool = false
    @Published var completionMessage: String = ""
    @Published var timeSavedSeconds: Int? = nil
    @Published var showPINSetupPrompt: Bool = false  // Prompt to set up PIN after first completion
    private var pendingSession: (activity: String, icon: String, allocatedTime: Int, actualTime: Int)?

    // Track time for early completion
    var actualTimeSpent: Int {
        totalTime - timeRemaining
    }

    private var timer: Timer?
    private let soundManager = SoundManager.shared
    private let settings = TimerSettings.shared
    private var announcedMilestones: Set<Int> = []

    var progress: Double {
        // Full circle represents 1 hour (3600 seconds)
        let oneHour = 3600.0
        return Double(timeRemaining) / oneHour
    }

    // Relative progress for background colors (based on time set, not hour)
    var relativeProgress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }

    var timeRemainingFormatted: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var pauseDurationFormatted: String? {
        guard let pausedAt = pausedAt, !isRunning else { return nil }
        let duration = Int(Date().timeIntervalSince(pausedAt))
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Encouraging messages based on progress
    var encouragingMessage: String {
        guard totalTime > 0 && timeRemaining > 0 else { return "" }

        let percentage = relativeProgress

        if percentage > 0.9 {
            return "Let's do this! 💪"
        } else if percentage > 0.75 {
            return "Great start!"
        } else if percentage > 0.5 {
            return "Halfway there!"
        } else if percentage > 0.25 {
            return "Keep going!"
        } else if percentage > 0.1 {
            return "Almost done!"
        } else {
            return "Final stretch! 🎯"
        }
    }

    var backgroundGradientColors: [Color] {
        // Kid-friendly, soft gradient colors
        // Idle state: Soft dreamy purple-blue (calming welcome screen)
        guard totalTime > 0 else {
            return [Color(red: 0.55, green: 0.45, blue: 0.95), Color(red: 0.4, green: 0.7, blue: 0.95)]
        }

        let percentage = relativeProgress

        if percentage > 0.75 {
            // Plenty of time: Calm sky blue - relaxed, no rush
            return [Color(red: 0.4, green: 0.7, blue: 0.95), Color(red: 0.5, green: 0.8, blue: 0.9)]
        } else if percentage > 0.5 {
            // Good time: Soft teal/mint - still comfortable
            return [Color(red: 0.4, green: 0.8, blue: 0.75), Color(red: 0.5, green: 0.85, blue: 0.7)]
        } else if percentage > 0.25 {
            // Getting there: Warm peach/apricot - gentle attention
            return [Color(red: 1.0, green: 0.75, blue: 0.5), Color(red: 1.0, green: 0.65, blue: 0.45)]
        } else if percentage > 0.1 {
            // Hurry up: Soft coral - friendly urgency
            return [Color(red: 1.0, green: 0.55, blue: 0.5), Color(red: 1.0, green: 0.5, blue: 0.55)]
        } else {
            // Almost done: Warm pink-red - excitement to finish!
            return [Color(red: 1.0, green: 0.45, blue: 0.5), Color(red: 0.95, green: 0.4, blue: 0.55)]
        }
    }

    func startTimer(minutes: Int, activity: String = "Timer", activityIcon: String = "clock.fill") {
        stopTimer()
        totalTime = minutes * 60
        timeRemaining = totalTime
        isRunning = true
        currentActivity = activity
        currentActivityIcon = activityIcon
        pausedAt = nil
        announcedMilestones.removeAll()
        currentMilestone = nil
        milestoneMessage = ""

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            completeTimer()
            return
        }

        timeRemaining -= 1

        // Play tick sound if enabled
        if settings.tickSoundEnabled {
            soundManager.playTickSound()
        }

        // Check for milestones
        checkMilestones()
    }

    private func checkMilestones() {
        let halfwayPoint = totalTime / 2

        // Halfway milestone
        if timeRemaining == halfwayPoint && !announcedMilestones.contains(halfwayPoint) && totalTime >= 120 {
            announcedMilestones.insert(halfwayPoint)
            triggerMilestone(.halfway, message: "Halfway there! Keep it up!")
        }

        // 5 minutes remaining
        if timeRemaining == 300 && !announcedMilestones.contains(300) && totalTime > 300 {
            announcedMilestones.insert(300)
            triggerMilestone(.fiveMinutes, message: "5 minutes left!")
        }

        // 2 minutes remaining
        if timeRemaining == 120 && !announcedMilestones.contains(120) && totalTime > 120 {
            announcedMilestones.insert(120)
            triggerMilestone(.twoMinutes, message: "2 minutes to go!")
        }

        // 1 minute remaining (existing warning)
        if timeRemaining == 60 && !announcedMilestones.contains(60) {
            announcedMilestones.insert(60)
            triggerMilestone(.oneMinute, message: "Final minute!")
            soundManager.playWarningSound()
        }

        // 30 seconds remaining
        if timeRemaining == 30 && !announcedMilestones.contains(30) && totalTime >= 60 {
            announcedMilestones.insert(30)
            triggerMilestone(.thirtySeconds, message: "30 seconds - almost done!")
        }
    }

    private func triggerMilestone(_ type: MilestoneType, message: String) {
        currentMilestone = type
        milestoneMessage = message

        // Play milestone sound
        if type != .oneMinute { // Don't double-play with warning sound
            soundManager.playMilestoneSound()
        }

        // Clear milestone after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.currentMilestone == type {
                self?.currentMilestone = nil
                self?.milestoneMessage = ""
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func resetTimer() {
        stopTimer()
        timeRemaining = 0
        totalTime = 0
        currentActivity = ""
        currentActivityIcon = ""
        pausedAt = nil
        announcedMilestones.removeAll()
        currentMilestone = nil
        milestoneMessage = ""
        awaitingVerification = false
        isVerified = false
        completionMessage = ""
        timeSavedSeconds = nil
        pendingSession = nil
        showPINSetupPrompt = false
    }

    // MARK: - Early Completion

    func finishEarly() {
        guard totalTime > 0 && timeRemaining > 0 else { return }

        let timeSpent = actualTimeSpent
        let saved = totalTime - timeSpent

        // Store pending session data - finished before timer ran out
        pendingSession = (
            activity: currentActivity,
            icon: currentActivityIcon,
            allocatedTime: totalTime,
            actualTime: timeSpent
        )

        // Store time saved for display
        timeSavedSeconds = saved > 0 ? saved : nil

        // Set timeRemaining to 0 so celebration shows
        timeRemaining = 0

        stopTimer()
        soundManager.playCompletionSound()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if settings.isVerificationEnabled {
            // Wait for parent verification before saving
            awaitingVerification = true
            isVerified = false
        } else {
            // No PIN set - prompt user to set one up
            showPINSetupPrompt = true
        }
    }

    private func completeTimer() {
        // Store pending session data - used full allocated time
        pendingSession = (
            activity: currentActivity,
            icon: currentActivityIcon,
            allocatedTime: totalTime,
            actualTime: totalTime  // Timer ran to completion
        )

        stopTimer()
        soundManager.playCompletionSound()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if settings.isVerificationEnabled {
            // Wait for parent verification before saving
            awaitingVerification = true
            isVerified = false
        } else {
            // No PIN set - prompt user to set one up
            showPINSetupPrompt = true
        }
    }

    // MARK: - Parent Verification

    func verifyPIN(_ pin: String) -> Bool {
        guard let correctPIN = settings.parentPIN else { return false }
        return pin == correctPIN
    }

    func confirmVerification() {
        awaitingVerification = false
        isVerified = true
        saveCompletedSession()
    }

    // Called when user skips PIN setup ("Maybe Later")
    func skipPINSetup() {
        showPINSetupPrompt = false
        isVerified = true
        saveCompletedSession()
    }

    // Called when user successfully sets up PIN
    func completePINSetup() {
        showPINSetupPrompt = false
        // Now PIN is enabled, so require verification
        awaitingVerification = true
        isVerified = false
    }

    private func saveCompletedSession() {
        guard let session = pendingSession else { return }

        settings.addSession(
            activity: session.activity,
            activityIcon: session.icon,
            allocatedTime: session.allocatedTime,
            actualTime: session.actualTime
        )

        // Set completion message for visual display
        let timeSaved = session.allocatedTime - session.actualTime
        if timeSaved > 60 {
            completionMessage = "You finished \(session.activity) \(timeSaved / 60) min early!"
        } else if timeSaved > 0 {
            completionMessage = "You finished \(session.activity) early!"
        } else {
            completionMessage = "You finished your \(session.activity)!"
        }

        pendingSession = nil
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        pausedAt = Date()
    }

    func resumeTimer() {
        guard timeRemaining > 0 else { return }
        isRunning = true
        pausedAt = nil

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
}
