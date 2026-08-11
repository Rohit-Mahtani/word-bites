import SwiftUI
import WordBitesKit

/// Lets the player type in their own 11 tiles instead of generating a
/// board. They only choose letters (and each double tile's orientation) —
/// where the tiles land on the board is still randomized at deal time,
/// scattered with the same no-touching rule as a generated board.
struct CustomBoardView: View {
    @ObservedObject var store: CustomBoardStore
    let onBack: () -> Void
    let onShowPresets: () -> Void
    @FocusState private var focusedField: CustomBoardFocusField?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                    Text("Custom Board")
                        .font(Theme.archivoBold(26))
                        .foregroundColor(Theme.ink)
                    Spacer()
                    Button(action: onShowPresets) {
                        Text("Presets")
                            .font(Theme.archivoMedium(13))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Single Tiles", progress: "\(store.filledSingleCount)/\(store.singles.count)")
                            FlowLayout(spacing: 9) {
                                ForEach(store.singles.indices, id: \.self) { index in
                                    LetterInputTile(
                                        letter: $store.singles[index].letter,
                                        field: .single(index),
                                        focusedField: $focusedField,
                                        onFilled: { advanceFocus(from: .single(index)) }
                                    )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Double Tiles", progress: "\(store.filledDoubleCount)/\(store.doubles.count)")
                            Text("Tap the rotate button to flip a tile between horizontal and vertical.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMutedLight)

                            VStack(spacing: 14) {
                                ForEach(store.doubles.indices, id: \.self) { index in
                                    DoubleTileInput(
                                        doubleTile: $store.doubles[index],
                                        index: index,
                                        focusedField: $focusedField,
                                        onFilled: advanceFocus
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(20)
        }
    }

    private func advanceFocus(from field: CustomBoardFocusField) {
        focusedField = store.nextEmptyField(after: field)
    }

    private func sectionHeader(_ title: String, progress: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textMutedMid)
            Spacer()
            Text(progress)
                .font(Theme.archivoMedium(13))
                .foregroundColor(Theme.textMutedMid)
        }
    }
}

private struct DoubleTileInput: View {
    @Binding var doubleTile: CustomDoubleTile
    let index: Int
    var focusedField: FocusState<CustomBoardFocusField?>.Binding
    let onFilled: (CustomBoardFocusField) -> Void

    private var isComplete: Bool {
        doubleTile.firstLetter != nil && doubleTile.secondLetter != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            pairShape

            Button {
                doubleTile.orientation = doubleTile.orientation == .horizontal ? .vertical : .horizontal
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textMutedDark)
                    .frame(width: 42, height: 42)
                    .background(Theme.textMutedDark.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // Rendered as one fused shape (single background/border spanning both
    // halves, no visible seam) -- each half still self-reports its own
    // filled/empty background, but only the container draws the border.
    private var pairShape: some View {
        Group {
            if doubleTile.orientation == .horizontal {
                HStack(spacing: 0) { firstLetterTile; secondLetterTile }
            } else {
                VStack(spacing: 0) { firstLetterTile; secondLetterTile }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isComplete ? Theme.tileBorder : Theme.emptySlotBorder.opacity(0.55),
                    style: StrokeStyle(lineWidth: isComplete ? 1 : 1.5, dash: isComplete ? [] : [4, 3])
                )
        )
    }

    // A double tile's two letters must differ -- rejects a typed letter
    // that would duplicate the other half.
    private var firstLetterTile: some View {
        LetterInputTile(
            letter: $doubleTile.firstLetter,
            size: 56,
            field: .doubleFirst(index),
            focusedField: focusedField,
            cornerRadius: 0,
            showBorder: false,
            isValid: { $0 != doubleTile.secondLetter },
            onFilled: { onFilled(.doubleFirst(index)) }
        )
    }

    private var secondLetterTile: some View {
        LetterInputTile(
            letter: $doubleTile.secondLetter,
            size: 56,
            field: .doubleSecond(index),
            focusedField: focusedField,
            cornerRadius: 0,
            showBorder: false,
            isValid: { $0 != doubleTile.firstLetter },
            onFilled: { onFilled(.doubleSecond(index)) }
        )
    }
}
