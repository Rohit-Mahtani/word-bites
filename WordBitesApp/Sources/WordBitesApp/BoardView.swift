import SwiftUI
import WordBitesKit

/// Tracks which tile (if any) currently owns the active drag, shared by
/// reference across every tile's gesture so each check reads the CURRENT
/// value at the moment it runs, not a value captured once. A plain struct
/// `let` (the previous mechanism for this) went stale mid-gesture -- an
/// already-in-progress gesture keeps using whatever value its own view
/// instance was constructed with, so reassigning `BoardView`'s state from
/// inside one tile's gesture didn't reliably reach a different tile's
/// already-running one. Reading `activeDrag.draggingTileID` through a
/// shared class reference instead has no such staleness: it's the same
/// storage location no matter which gesture, or when, reads it.
final class ActiveDragCoordinator {
    var draggingTileID: UUID?
}

/// The felt board: 8x9 grid, tiles absolutely positioned and draggable.
/// A tile's live drag is just a visual offset from its last committed
/// position — on release we compute the nearest cell, ask the view model
/// to commit or reject it, then animate to wherever it actually lands.
///
/// Takes `tiles`/`placements` as plain values (plus plain closures for the
/// two view-model actions it needs) rather than `@ObservedObject var
/// viewModel: GameViewModel` directly. `GameViewModel` is one big
/// `ObservableObject` covering everything from tile placement to the HUD's
/// once-a-second timer tick -- an `@ObservedObject` subscription reacts to
/// *any* published change on the whole object, so holding one directly
/// would re-render this entire board every single second even though
/// nothing about the board itself changed. Equatable + `.equatable()` at
/// the call site lets SwiftUI skip re-invoking `body` altogether on those
/// irrelevant updates, since it can just compare the actual values.
struct BoardView: View, Equatable {
    let tiles: [Tile]
    let placements: [UUID: Placement]
    let cellSize: CGFloat
    let canPlace: (UUID, Position) -> Bool
    let attemptMove: (UUID, Position) -> Void

    @State private var draggingTileID: UUID?
    @State private var dragCandidateOrigin: Position?
    // Plain @State (not @StateObject -- ActiveDragCoordinator isn't even
    // Observable) purely for stable identity: the same instance survives
    // BoardView's own re-renders, and nothing here subscribes to it.
    @State private var activeDrag = ActiveDragCoordinator()

    static func == (lhs: BoardView, rhs: BoardView) -> Bool {
        lhs.tiles == rhs.tiles && lhs.placements == rhs.placements && lhs.cellSize == rhs.cellSize
    }

    private var pitch: CGFloat { cellSize + Theme.gap }
    private var boardWidth: CGFloat { CGFloat(Board.columnCount) * pitch - Theme.gap }
    private var boardHeight: CGFloat { CGFloat(Board.rowCount) * pitch - Theme.gap }

    var body: some View {
        ZStack(alignment: .topLeading) {
            boardBackground
            dropZoneHighlight
            ForEach(tiles, id: \.id) { tile in
                if let placement = placements[tile.id] {
                    tileView(tile: tile, placement: placement)
                }
            }
        }
        .frame(width: boardWidth, height: boardHeight)
    }

    private var boardBackground: some View {
        ZStack {
            Theme.boardPanel
            gridLines
        }
        .frame(width: boardWidth, height: boardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // Approximates the spec's inset shadow (`inset 0 2px 10px
        // rgba(80,55,20,.2)`) -- SwiftUI has no native inset shadow, so a
        // soft inward-facing edge stroke stands in for it.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.dotTextureBase.opacity(0.2), lineWidth: 3)
                .blur(radius: 3)
                .mask(RoundedRectangle(cornerRadius: 10))
        )
    }

    private var gridLines: some View {
        Path { path in
            for c in 1..<Board.columnCount {
                let x = CGFloat(c) * pitch - Theme.gap / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: boardHeight))
            }
            for r in 1..<Board.rowCount {
                let y = CGFloat(r) * pitch - Theme.gap / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: boardWidth, y: y))
            }
        }
        .stroke(Theme.dotTextureBase.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
    }

    /// Highlights the cell(s) the currently-dragged tile would land on if
    /// released right now — green if that spot's valid, red if it isn't.
    @ViewBuilder
    private var dropZoneHighlight: some View {
        if let tileID = draggingTileID,
           let origin = dragCandidateOrigin,
           let tile = tiles.first(where: { $0.id == tileID }) {
            let orientation = orientation(for: tile)
            let cells = Board.cells(origin: origin, cellCount: tile.cellCount, direction: orientation)
            let valid = canPlace(tileID, origin)

            ForEach(cells.indices, id: \.self) { index in
                let cell = cells[index]
                if cell.column >= 0, cell.column < Board.columnCount, cell.row >= 0, cell.row < Board.rowCount {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(valid ? Color.green.opacity(0.35) : Color.red.opacity(0.35))
                        .frame(width: cellSize, height: cellSize)
                        .position(
                            x: CGFloat(cell.column) * pitch + cellSize / 2,
                            y: CGFloat(cell.row) * pitch + cellSize / 2
                        )
                }
            }
        }
    }

    private func orientation(for tile: Tile) -> TileOrientation {
        if case .double(let d) = tile { return d.orientation }
        return .horizontal
    }

    private func tileSize(for tile: Tile) -> CGSize {
        switch tile {
        case .single:
            return CGSize(width: cellSize, height: cellSize)
        case .double(let d):
            return d.orientation == .horizontal
                ? CGSize(width: cellSize * 2 + Theme.gap, height: cellSize)
                : CGSize(width: cellSize, height: cellSize * 2 + Theme.gap)
        }
    }

    private func topLeft(for placement: Placement) -> CGPoint {
        CGPoint(x: CGFloat(placement.origin.column) * pitch, y: CGFloat(placement.origin.row) * pitch)
    }

    private func tileView(tile: Tile, placement: Placement) -> some View {
        DraggableTileView(
            tile: tile,
            cellSize: cellSize,
            pitch: pitch,
            base: topLeft(for: placement),
            size: tileSize(for: tile),
            activeDrag: activeDrag,
            onDragStart: {
                draggingTileID = tile.id
                FeedbackPlayer.tilePickedUp()
            },
            onDragCandidateChange: { candidate in
                // Skip the write (and the re-render + canPlace check it
                // triggers) when the rounded candidate cell hasn't actually
                // changed -- most sub-pixel touch deltas during a drag
                // round to the same cell as the previous event.
                if dragCandidateOrigin != candidate {
                    dragCandidateOrigin = candidate
                }
            },
            onDragEnd: { finalOrigin in
                attemptMove(tile.id, finalOrigin)
                draggingTileID = nil
                dragCandidateOrigin = nil
                FeedbackPlayer.tilePlaced()
            }
        )
        .zIndex(draggingTileID == tile.id ? 10 : 1)
    }
}

/// One tile's own live drag state and gesture, isolated from `BoardView`'s
/// state on purpose: `dragOffset`/`isDragging` used to live in `BoardView`
/// (`[UUID: CGSize]` + a `draggingTileID`), so every touch-move event on
/// *any* tile mutated `BoardView`'s own `@State` and forced its `body` to
/// re-run — which reconstructed all 11 tiles' full view (gradient, grain
/// texture, border, two shadows) on every single frame of a drag, not just
/// the one tile actually moving. A screen recording of real on-device
/// dragging confirmed this wasn't just perception: its own frame timestamps
/// showed genuine dropped frames (many 33-50ms gaps instead of the expected
/// ~17ms) concentrated exactly during dragging.
///
/// Keeping the live offset here instead means only *this* tile's `body`
/// re-runs as it's dragged — SwiftUI skips re-rendering a child view whose
/// own input properties (`tile`, `base`, ...) are unchanged between parent
/// re-renders, so the other 10 tiles do no work per frame. `BoardView`
/// still needs to know which tile is dragging (for the drop-zone highlight
/// and z-index), so that part is reported up via
/// `onDragStart`/`onDragCandidateChange`/`onDragEnd` rather than duplicated
/// here.
///
/// Fires pickup on touch, not just after real movement, via
/// `LongPressGesture(minimumDuration: 0).sequenced(before: DragGesture())`
/// -- a single composite gesture per tile, not two. This exact mechanism is
/// the result of five attempts, four of them reverted or corrected:
/// 1. Lowering this gesture's own `minimumDistance` to 0 -- every sub-pixel
///    touch jitter got processed as a live drag event, the confirmed cause
///    of persistent dragging choppiness.
/// 2. A second, separate `DragGesture(minimumDistance: 0)` alongside this
///    one via `.gesture` + `.simultaneousGesture` -- two simultaneous
///    `DragGesture`s of different minimum distances on one view left
///    SwiftUI/UIKit's gesture-recognizer state broken; tiles needed to be
///    pressed twice to respond at all.
/// 3. This same `.sequenced` composite, but with a SEPARATE
///    `DragGesture()` for movement attached via `.simultaneousGesture` (so
///    a `LongPressGesture(maximumDistance: .infinity)` alone could own
///    release-detection) -- movement stopped working *entirely*.
///    `.simultaneousGesture` alongside a `LongPressGesture` on this view is
///    now also a confirmed trap, not just a theoretical risk.
/// 4. Back to this composite gesture, unchanged from attempt 1, but with a
///    cross-tile `isAnyOtherTileDragging` guard removed only from the
///    fresh-press case, so a stuck "still dragging" tile could no longer
///    block a *different* tile from starting. This didn't actually work --
///    `isAnyOtherTileDragging` is a `let` captured on this struct at the
///    render that created it, and a still-in-progress gesture keeps using
///    that same captured value; reassigning `BoardView`'s `draggingTileID`
///    from inside the gesture doesn't retroactively update it before the
///    gesture's own next event.
/// 5. The `isAnyOtherTileDragging` cross-tile gate removed entirely, not
///    partially. Each tile's press/drag/release is now fully independent
///    of every other tile's state -- nothing here can be stale, because
///    nothing here reads any other tile's state at all. Fixed the
///    gameplay-blocking part of the original bug, but left a cosmetic gap:
///    this gesture's own `onEnded` still didn't fire for a release that
///    never crossed `DragGesture`'s minimum distance, since the
///    `DragGesture` half never began -- so a tile touched and released
///    without moving wouldn't play its own drop sound or drop its
///    lifted-shadow look until dragged for real.
/// 6. Fixes that gap by using `DragGesture(minimumDistance: 0)` for the
///    second phase instead of the default -- this makes it begin (and
///    therefore reliably end/fire `onEnded`) on literally any touch,
///    including zero movement. That reintroduces the exact condition
///    attempt 1 warned about (every sub-pixel jitter now generates an
///    event), so the movement-threshold check that `DragGesture`'s own
///    `minimumDistance` used to do internally is now done by hand, in
///    `exceedsMovementThreshold(_:)` below, before ever touching
///    `dragOffset` -- the state-write frequency (the actual cost that
///    caused the original choppiness) is unchanged from the working
///    default-minimumDistance version; only the underlying recognizer's
///    own begin/end lifecycle is different, which is exactly the part
///    that needed to change.
/// 7. Attempt 5 removed cross-tile exclusivity entirely, which meant two
///    different fingers on two different tiles really could both drag at
///    once. Reintroduced via `ActiveDragCoordinator` (a shared class
///    reference, not a captured struct `let`) rather than bringing back
///    the exact mechanism from attempt 4 -- reading a shared reference's
///    property is never stale the way a captured value could be, and
///    attempt 6 already made `onEnded` fire reliably on every release, so
///    the original "stuck forever" failure mode this exclusivity check
///    used to cause is independently fixed too. First version of this
///    guarded `.second`'s entry on `activeDrag.draggingTileID == tile.id`
///    alone -- confirmed on-device this broke movement *entirely*: this
///    composite gesture doesn't reliably deliver a standalone `.first(true)`
///    event before `.second` starts arriving, and `.first(true)` was the
///    only branch that acquired the lock, so `.second` could never
///    bootstrap and every tile's movement was rejected.
/// 8. Current: `.second` now has the same acquire-or-already-mine guard as
///    `.first(true)`, and independently sets `activeDrag.draggingTileID`
///    in its own bootstrap block -- restores the redundant "either branch
///    can be the one that starts things" robustness the pre-exclusivity
///    code always had, while still rejecting a genuinely different tile
///    that doesn't already hold the lock.
private struct DraggableTileView: View {
    let tile: Tile
    let cellSize: CGFloat
    let pitch: CGFloat
    let base: CGPoint
    let size: CGSize
    let activeDrag: ActiveDragCoordinator
    let onDragStart: () -> Void
    let onDragCandidateChange: (Position?) -> Void
    let onDragEnd: (Position) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        TileView(tile: tile, cellSize: cellSize, isDragging: isDragging)
            .frame(width: size.width, height: size.height)
            .position(x: base.x + size.width / 2 + dragOffset.width, y: base.y + size.height / 2 + dragOffset.height)
            // Scoped to just this tile's settled position (`base`, driven by
            // `placement`) so only the tile that actually moved animates.
            // Wrapping the view-model mutation itself in `withAnimation`
            // (an earlier approach) puts every tile, the HUD, and the
            // board's own layout into one shared animated transaction --
            // which both blocked a new drag gesture on a different tile
            // from being recognized until that transaction settled, and let
            // unrelated layout (the board's position) get swept into the
            // same animation, causing it to visibly jitter.
            // response shortens how long the settle takes; dampingFraction
            // closer to 1 cuts down the springy overshoot/bounce that read
            // as "floaty" -- still a spring curve (eased, not a hard cut),
            // just a tighter and quicker one.
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: base)
            .gesture(
                LongPressGesture(minimumDuration: 0)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            // Only allowed to start if no OTHER tile
                            // currently owns the drag -- reads
                            // activeDrag.draggingTileID fresh through the
                            // shared reference, not a captured snapshot, so
                            // this can't go stale mid-gesture the way the
                            // old struct-`let` version could.
                            guard activeDrag.draggingTileID == nil || activeDrag.draggingTileID == tile.id else { return }
                            // Finger touched down -- report the pickup and
                            // the tile's own current cell as the candidate,
                            // so the drop-zone highlight appears immediately
                            // under the tile, before any movement.
                            if !isDragging {
                                isDragging = true
                                activeDrag.draggingTileID = tile.id
                                onDragStart()
                                reportCandidate()
                            }
                        case .second(true, let drag):
                            // Same acquire-or-already-mine guard as
                            // .first(true) above, independently -- this
                            // composite gesture doesn't reliably deliver a
                            // standalone .first(true) event before .second
                            // starts arriving (confirmed on-device: making
                            // .second depend on .first having already run
                            // broke movement entirely), so .second must be
                            // able to bootstrap isDragging/the lock on its
                            // own too, not just check it.
                            guard activeDrag.draggingTileID == nil || activeDrag.draggingTileID == tile.id else { return }
                            if !isDragging {
                                isDragging = true
                                activeDrag.draggingTileID = tile.id
                                onDragStart()
                            }
                            if let drag, exceedsMovementThreshold(drag.translation) {
                                dragOffset = drag.translation
                                reportCandidate()
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { value in
                        // Ignore a release from a tile whose own press was
                        // never recognized in the first place.
                        guard isDragging else { return }
                        if case .second(true, let drag?) = value, exceedsMovementThreshold(drag.translation) {
                            dragOffset = drag.translation
                        }
                        let newTopLeft = CGPoint(
                            x: base.x + dragOffset.width,
                            y: base.y + dragOffset.height
                        )
                        let col = Int((newTopLeft.x / pitch).rounded())
                        let row = Int((newTopLeft.y / pitch).rounded())
                        onDragEnd(Position(column: col, row: row))
                        dragOffset = .zero
                        isDragging = false
                        if activeDrag.draggingTileID == tile.id {
                            activeDrag.draggingTileID = nil
                        }
                    }
            )
    }

    // Matches SwiftUI's own default DragGesture minimumDistance -- see the
    // doc comment above (attempt 6) for why this check now lives here
    // instead of being left to the gesture itself.
    private static let movementThreshold: CGFloat = 10

    private func exceedsMovementThreshold(_ translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) > Self.movementThreshold
    }

    /// Reports the board cell under the tile's current live position
    /// (`base` offset by `dragOffset`, which is `.zero` at touch-down) --
    /// shared by both the initial press and every subsequent drag update so
    /// the highlight/candidate math has one definition.
    private func reportCandidate() {
        let liveTopLeft = CGPoint(x: base.x + dragOffset.width, y: base.y + dragOffset.height)
        onDragCandidateChange(Position(
            column: Int((liveTopLeft.x / pitch).rounded()),
            row: Int((liveTopLeft.y / pitch).rounded())
        ))
    }
}
