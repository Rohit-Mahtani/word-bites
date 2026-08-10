import Foundation

/// Persisted on/off state for background music and sound effects, toggled
/// from the welcome screen. Both default to on -- `UserDefaults.bool` alone
/// would default an unset key to `false`, so absence is treated explicitly
/// as "on" instead.
enum AudioSettings {
    private static let musicKey = "wordbites.musicEnabled"
    private static let sfxKey = "wordbites.sfxEnabled"

    static var isMusicEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: musicKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: musicKey) }
    }

    static var isSFXEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: sfxKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: sfxKey) }
    }
}
