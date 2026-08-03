import SwiftUI

@main
struct WordBitesApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .buttonStyle(HapticButtonStyle())
                .onAppear { MusicPlayer.start() }
        }
    }
}
