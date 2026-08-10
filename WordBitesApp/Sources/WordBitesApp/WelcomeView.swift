import SwiftUI

struct WelcomeView: View {
    let onSinglePlayer: () -> Void
    let onShowStats: () -> Void

    @State private var isMusicOn = AudioSettings.isMusicEnabled
    @State private var isSFXOn = AudioSettings.isSFXEnabled

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        AudioToggleButton(systemName: "music.note", isOn: $isMusicOn) { enabled in
                            MusicPlayer.setEnabled(enabled)
                        }
                        AudioToggleButton(systemName: "speaker.wave.2.fill", isOn: $isSFXOn) { enabled in
                            AudioSettings.isSFXEnabled = enabled
                        }
                    }
                }
                Spacer()
            }
            .padding(20)

            VStack(spacing: 34) {
                Spacer()

                VStack(spacing: 18) {
                    TileLogoView(text: "ALIGNED", tileSize: 36, fontSize: 19, spacing: 6)
                    Text("Welcome to Aligned")
                        .font(Theme.archivoMedium(14))
                        .italic()
                        .foregroundColor(Theme.textMutedMid)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onSinglePlayer) {
                        Text("Single Player")
                            .font(Theme.archivoMedium(16))
                            .foregroundColor(Theme.ink)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onShowStats) {
                        Text("High Scores")
                            .font(Theme.archivoMedium(16))
                            .foregroundColor(Theme.textMutedDark)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 15)
                            .background(Theme.textMutedDark.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.textMutedDark.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(24)
        }
    }
}

/// A small round icon button that toggles `isOn` and reports the new value
/// to `onChange` -- used for the welcome screen's music/sound-effects
/// switches. Off is shown as a diagonal line drawn across the icon (rather
/// than relying on an SF Symbol "slash" variant existing for every icon
/// used here) so the same component works for any `systemName`.
private struct AudioToggleButton: View {
    let systemName: String
    @Binding var isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            isOn.toggle()
            onChange(isOn)
        } label: {
            ZStack {
                Circle().fill(Theme.textMutedDark.opacity(0.08))
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textMutedDark)
                if !isOn {
                    Rectangle()
                        .fill(Theme.textMutedDark)
                        .frame(width: 1.6, height: 24)
                        .rotationEffect(.degrees(45))
                }
            }
            .frame(width: 38, height: 38)
        }
    }
}
