import SwiftUI

/// Home screen redesign (option 16d, 2026-08). Background is a warm
/// spotlight rather than a flat wash, buttons are tall pills with a tile-
/// style "lift" shadow on the primary one, and the whole logo/subtitle/
/// buttons group is centered as one block between two equal spacers --
/// closing the dead gap the previous flat-wash/50pt-button layout had in
/// the middle of the screen. The wordmark logo and the audio toggle
/// buttons are unchanged from before this redesign, per the design spec.
struct WelcomeView: View {
    let onSinglePlayer: () -> Void
    let onShowStats: () -> Void

    @State private var isMusicOn = AudioSettings.isMusicEnabled
    @State private var isSFXOn = AudioSettings.isSFXEnabled

    var body: some View {
        ZStack {
            // A warm radial spotlight centered above the logo, rather than
            // a flat top-to-bottom wash. EllipticalGradient (not a plain
            // RadialGradient) so it isn't forced perfectly circular on a
            // tall phone screen.
            EllipticalGradient(
                gradient: Gradient(stops: [
                    .init(color: Theme.welcomeSpotlightTop, location: 0),
                    .init(color: Theme.welcomeSpotlightMid, location: 0.48),
                    .init(color: Theme.welcomeSpotlightBottom, location: 1.0)
                ]),
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadiusFraction: 0,
                endRadiusFraction: 1.0
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
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
                .padding(.trailing, 24)
                .padding(.top, 6)

                Spacer()

                VStack(spacing: 0) {
                    TileLogoView(text: "ALIGNED", tileSize: 36, fontSize: 19, spacing: 6)

                    Text("Welcome to Aligned")
                        .font(Theme.archivoMedium(15))
                        .italic()
                        .foregroundColor(Theme.textMutedMid)
                        .padding(.top, 14)

                    Button(action: onSinglePlayer) {
                        Text("Single Player")
                    }
                    .buttonStyle(WelcomePrimaryButtonStyle())
                    .padding(.top, 44)

                    Button(action: onShowStats) {
                        Text("High Scores")
                    }
                    .buttonStyle(WelcomeSecondaryButtonStyle())
                    .padding(.top, 16)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

/// Tall gold pill with a tile-style two-layer shadow: a hard "lift" block
/// directly below, plus a soft ambient shadow. Pressed state translates the
/// button down by exactly the lift shadow's own offset and collapses that
/// shadow's offset to 0 at the same time -- together they read as the
/// button physically settling onto the surface the shadow was implying,
/// rather than just dimming or scaling.
private struct WelcomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.archivoBold(18))
            .foregroundColor(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                LinearGradient(colors: [Theme.welcomeGoldTop, Theme.welcomeGoldBottom], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: Theme.welcomeGoldShadow, radius: 0, x: 0, y: configuration.isPressed ? 0 : 6)
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
            .offset(y: configuration.isPressed ? 6 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            // Mirrors HapticButtonStyle's own tap haptic -- this button
            // uses its own ButtonStyle for the pressed-state visuals above,
            // which replaces (rather than layers on top of) the app-root
            // HapticButtonStyle for this specific button, so the haptic
            // trigger is repeated here to not lose it.
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { FeedbackPlayer.buttonTapped() }
            }
    }
}

/// Outline-only pill -- transparent at rest, a faint fill while pressed.
private struct WelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.archivoSemiBold(18))
            .foregroundColor(Theme.textMutedDark)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(configuration.isPressed ? Theme.textMutedDark.opacity(0.08) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Theme.tileBorder, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { FeedbackPlayer.buttonTapped() }
            }
    }
}

/// A small round icon button that toggles `isOn` and reports the new value
/// to `onChange` -- used for the welcome screen's music/sound-effects
/// switches. Off is shown as a diagonal line drawn across the icon (rather
/// than relying on an SF Symbol "slash" variant existing for every icon
/// used here) so the same component works for any `systemName`.
///
/// Unchanged by the 2026-08 home screen redesign -- kept exactly as
/// shipped, per that design's own note to leave the audio buttons alone.
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
