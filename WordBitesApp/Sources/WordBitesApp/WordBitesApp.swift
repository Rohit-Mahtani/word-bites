import SwiftUI

@main
struct WordBitesApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .buttonStyle(HapticButtonStyle())
                .onAppear {
                    MusicPlayer.start()
                    // Forces SoundEffectPlayer's lazy singleton to
                    // initialize now (preloading every sound resource's
                    // bytes from disk) instead of on first use -- which
                    // would otherwise be whatever button or tile the
                    // player first touches, mid-interaction.
                    _ = SoundEffectPlayer.shared
                }
        }
    }
}
