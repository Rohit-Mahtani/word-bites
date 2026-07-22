import SwiftUI

struct FoundWordsView: View {
    let words: [(word: String, points: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORDS FOUND")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundColor(Theme.creamDim)

            if words.isEmpty {
                Text("Drag tiles together to spell something.")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundColor(Theme.creamDim)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    // Words are unique per round (foundWordSet prevents
                    // duplicates), so the word text itself is a safe id.
                    FlowLayout(spacing: 6) {
                        ForEach(Array(words.reversed()), id: \.word) { entry in
                            HStack(spacing: 3) {
                                Text(entry.word)
                                Text("+\(entry.points)").foregroundColor(Theme.accent).fontWeight(.bold)
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Theme.cream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxHeight: 90)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.wood, Theme.woodDeep], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Minimal wrapping layout for the word chips — SwiftUI's HStack doesn't wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
