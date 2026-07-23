import SwiftUI
import WordBitesKit

/// Lets the player type in their own 11 tiles instead of generating a
/// board. They only choose letters (and each double tile's orientation) —
/// where the tiles land on the board is still randomized at deal time,
/// scattered with the same no-touching rule as a generated board.
struct CustomBoardView: View {
    @ObservedObject var store: CustomBoardStore
    let onBack: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.pageGlow, Theme.pageDeep],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 10,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                    Text("Custom Board")
                        .font(.custom("Georgia-Bold", size: 18))
                        .foregroundColor(Theme.pageText)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Single Tiles", progress: "\(store.filledSingleCount)/\(store.singles.count)")
                            FlowLayout(spacing: 10) {
                                ForEach(store.singles.indices, id: \.self) { index in
                                    LetterInputTile(letter: $store.singles[index].letter)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Double Tiles", progress: "\(store.filledDoubleCount)/\(store.doubles.count)")
                            Text("Tap the rotate button to flip a tile between horizontal and vertical.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.pageTextDim)

                            VStack(spacing: 14) {
                                ForEach(store.doubles.indices, id: \.self) { index in
                                    DoubleTileInput(doubleTile: $store.doubles[index])
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

    private func sectionHeader(_ title: String, progress: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
            Spacer()
            Text(progress)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .foregroundColor(Theme.pageTextDim)
    }
}

private struct DoubleTileInput: View {
    @Binding var doubleTile: CustomDoubleTile

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if doubleTile.orientation == .horizontal {
                    HStack(spacing: 2) {
                        LetterInputTile(letter: $doubleTile.firstLetter)
                        LetterInputTile(letter: $doubleTile.secondLetter)
                    }
                } else {
                    VStack(spacing: 2) {
                        LetterInputTile(letter: $doubleTile.firstLetter)
                        LetterInputTile(letter: $doubleTile.secondLetter)
                    }
                }
            }

            Spacer()

            Button {
                doubleTile.orientation = doubleTile.orientation == .horizontal ? .vertical : .horizontal
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.pageText)
                    .frame(width: 40, height: 40)
                    .background(Theme.pageText.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }
}
