import AVFoundation
import UIKit

@MainActor
class SoundManager {
    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    func playCompletionSound() {
        playSystemSound(1016)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.playSystemSound(1016)
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func playWarningSound() {
        playSystemSound(1053)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func playTickSound() {
        // Soft tick sound
        playSystemSound(1104)
    }

    func playMilestoneSound() {
        // Pleasant chime for milestones
        playSystemSound(1054)

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func playSystemSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
}
