import SwiftUI

/// A reusable LazyVGrid that allows the user to select multiple photos by
/// long-pressing and then dragging their finger across cells – behaviour that
/// mirrors Apple Photos’ multi-select gesture. The currently highlighted
/// selection is exposed through the `selected` binding so parent views can
/// perform bulk actions (delete, favourite, restore, etc.).
struct SelectablePhotoGrid: View {
    // MARK: – Public API
    let photos: [Photo]
    @Binding var selected: Set<Photo>
    @Binding var isSelecting: Bool
    var onTapSingle: ((Photo) -> Void)? = nil // Called when not in selection mode.

    // MARK: – Private state
    @State private var cellFrames: [UUID: CGRect] = [:]
    @GestureState private var dragLocation: CGPoint = .zero

    // Grid configuration
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let spacing: CGFloat = 12

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(photos) { photo in
                    PhotoCell(
                        photo: photo,
                        isSelected: selected.contains(photo)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelecting {
                            toggle(photo)
                        } else {
                            onTapSingle?(photo)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.15) {
                        // Enter selection mode & select initial photo
                        if !isSelecting {
                            isSelecting = true
                            selected = Set([photo])
                        }
                    }
                }
            }
            .padding(spacing)
            // Coordinate space is needed to translate global drag coordinates into
            // the grid’s local space when checking which frame contains the point.
            .coordinateSpace(name: "photoGrid")
            // Recognise selection drag alongside native scrolling so scrolling still works
            .simultaneousGesture(selectionDragGesture)
        }
        // Collect cell frames via a preference key so we can hit-test during the drag
        .onPreferenceChange(PhotoFramePreferenceKey.self) { value in
            cellFrames = value
        }
    }

    // MARK: – Drag Gesture
    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragLocation) { value, state, _ in
                state = value.location
                if isSelecting {
                    updateSelection(at: value.location)
                }
            }
    }

    private func updateSelection(at location: CGPoint) {
        for (id, frame) in cellFrames {
            if frame.contains(location) {
                if let photo = photos.first(where: { $0.id == id }) {
                    selected.insert(photo)
                }
            }
        }
    }

    private func toggle(_ photo: Photo) {
        if selected.contains(photo) {
            selected.remove(photo)
        } else {
            selected.insert(photo)
        }
    }
}

// MARK: – Photo Cell
private struct PhotoCell: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotoImageView(photo: photo, targetSize: CGSize(width: 110, height: 110))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .padding(6)
            }
        }
        .overlay(
            GeometryReader { geo in
                Color.clear.preference(
                    key: PhotoFramePreferenceKey.self,
                    value: [photo.id: geo.frame(in: .named("photoGrid"))]
                )
            }
        )
    }
}

// MARK: – PreferenceKey for cell frames
private struct PhotoFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
} 