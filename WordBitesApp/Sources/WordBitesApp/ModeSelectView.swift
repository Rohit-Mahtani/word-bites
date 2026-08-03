import SwiftUI
import WordBitesKit

struct ModeSelectView: View {
    let onBack: () -> Void
    let onStart: (GameMode, Double, Deal?) -> Void
    @ObservedObject var customBoardStore: CustomBoardStore
    let onEditCustomBoard: () -> Void
    @Binding var mode: GameMode
    @Binding var scoringPotential: Double

    private var canPlay: Bool {
        !customBoardStore.isCustomMode || customBoardStore.isComplete
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                }
                Spacer()

                VStack(spacing: 22) {
                    Text("Choose a Mode")
                        .font(Theme.archivoBold(26))
                        .foregroundColor(Theme.ink)

                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("MODE")
                            SegmentedPill(
                                options: [("Timed", GameMode.timed), ("Untimed", GameMode.untimed)],
                                selection: $mode
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("BOARD")
                            SegmentedPill(
                                options: [("Random", false), ("Custom", true)],
                                selection: $customBoardStore.isCustomMode
                            )
                            .onChange(of: customBoardStore.isCustomMode) { isCustom in
                                if isCustom { onEditCustomBoard() }
                            }

                            if customBoardStore.isCustomMode {
                                Button(action: onEditCustomBoard) {
                                    Text("Edit Custom Board (\(customBoardStore.filledSingleCount + customBoardStore.filledDoubleCount)/11)")
                                        .font(Theme.archivoMedium(13))
                                        .foregroundColor(Theme.ink)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Theme.textMutedDark.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            HStack {
                                sectionLabel("SCORING POTENTIAL")
                                Spacer()
                            }
                            Slider(value: $scoringPotential, in: 0...1)
                                .tint(Theme.goldDeep)
                                .disabled(customBoardStore.isCustomMode)

                            HStack {
                                Text("Average")
                                Spacer()
                                Text("Very High")
                            }
                            .font(Theme.archivoMedium(11))
                            .foregroundColor(Theme.textMutedMid)
                        }
                        .opacity(customBoardStore.isCustomMode ? 0.4 : 1)
                    }
                    .padding(20)
                    .background(Theme.textMutedDark.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.textMutedDark.opacity(0.16), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(spacing: 8) {
                        Button(action: {
                            let customDeal = customBoardStore.isCustomMode ? customBoardStore.buildDeal() : nil
                            onStart(mode, scoringPotential, customDeal)
                        }) {
                            Text("Play")
                                .font(Theme.archivoMedium(16))
                                .foregroundColor(Theme.ink)
                                .frame(maxWidth: 260)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .frame(maxWidth: 320)

                Spacer()
                Spacer()
            }
            .padding(20)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Theme.textMutedMid)
    }
}

/// A gold-pill segmented control matching the redesign's look — replaces
/// SwiftUI's native `.pickerStyle(.segmented)`, which can't be restyled to
/// match (solid gold active segment, translucent track, no native divider).
struct SegmentedPill<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Text(option.label)
                    .font(Theme.archivoMedium(14))
                    .foregroundColor(selection == option.value ? Theme.ink : Theme.textMutedMid)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selection == option.value ? Theme.gold : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        FeedbackPlayer.buttonTapped()
                        selection = option.value
                    }
            }
        }
        .padding(3)
        .background(Theme.textMutedDark.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Shared back arrow used across several screens (mode select, solver,
/// custom board, high scores, and the in-game HUD, which passes its own
/// tint/background to match the game screen's darker chrome).
struct BackButton: View {
    let action: () -> Void
    var tint: Color = Theme.textMutedDark
    var backgroundOpacity: Double = 0.08

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
