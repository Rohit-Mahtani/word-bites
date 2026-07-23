import SwiftUI
import WordBitesKit

struct ModeSelectView: View {
    let onBack: () -> Void
    let onStart: (GameMode, Double, Deal?) -> Void
    @ObservedObject var customBoardStore: CustomBoardStore
    let onEditCustomBoard: () -> Void

    @State private var mode: GameMode = .timed
    @State private var scoringPotential: Double = 0

    private var canPlay: Bool {
        !customBoardStore.isCustomMode || customBoardStore.isComplete
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.pageGlow, Theme.pageDeep],
                center: .init(x: 0.5, y: 0.2),
                startRadius: 10,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                }
                Spacer()

                VStack(spacing: 26) {
                    Text("Choose a mode")
                        .font(.custom("Georgia-Bold", size: 22))
                        .foregroundColor(Theme.pageText)

                    Picker("Mode", selection: $mode) {
                        Text("Timed").tag(GameMode.timed)
                        Text("Untimed").tag(GameMode.untimed)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)

                    VStack(spacing: 10) {
                        Text("BOARD")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(Theme.pageTextDim)

                        Picker("Board", selection: $customBoardStore.isCustomMode) {
                            Text("Random").tag(false)
                            Text("Custom").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                        .onChange(of: customBoardStore.isCustomMode) { isCustom in
                            if isCustom { onEditCustomBoard() }
                        }

                        if customBoardStore.isCustomMode {
                            Button(action: onEditCustomBoard) {
                                Text("Edit Custom Board (\(customBoardStore.filledSingleCount + customBoardStore.filledDoubleCount)/11)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.pageText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        Text("SCORING POTENTIAL")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(Theme.pageTextDim)

                        Slider(value: $scoringPotential, in: 0...1)
                            .tint(Theme.accent)
                            .frame(maxWidth: 260)
                            .disabled(customBoardStore.isCustomMode)

                        HStack {
                            Text("Average")
                            Spacer()
                            Text("Very High")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.pageTextDim)
                        .frame(maxWidth: 260)
                    }
                    .opacity(customBoardStore.isCustomMode ? 0.4 : 1)

                    VStack(spacing: 8) {
                        Button(action: {
                            let customDeal = customBoardStore.isCustomMode ? customBoardStore.buildDeal() : nil
                            onStart(mode, scoringPotential, customDeal)
                        }) {
                            Text("Play")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.chromeText)
                                .frame(maxWidth: 260)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(!canPlay)
                        .opacity(canPlay ? 1 : 0.5)

                        if !canPlay {
                            Text("Fill in all 11 tiles on the custom board first.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.error)
                        }
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(20)
        }
    }
}

/// Shared back arrow used across several screens (mode select, solver,
/// custom board, and the in-game "back to home" button).
struct BackButton: View {
    let action: () -> Void
    var tint: Color = Theme.pageText
    var backgroundOpacity: Double = 0.1

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(backgroundOpacity))
                .clipShape(Circle())
        }
    }
}
