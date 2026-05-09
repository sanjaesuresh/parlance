import AudioToolbox

enum SoundService {
    static func play(_ event: SoundEvent) {
        guard UserDefaults.standard.bool(forKey: "soundEffectsEnabled") else { return }
        AudioServicesPlaySystemSound(event.soundID)
    }

    enum SoundEvent {
        case sessionComplete
        case xpEarned
        case achievementUnlocked

        var soundID: SystemSoundID {
            switch self {
            case .sessionComplete:      return 1315
            case .xpEarned:            return 1057
            case .achievementUnlocked: return 1304
            }
        }
    }
}
