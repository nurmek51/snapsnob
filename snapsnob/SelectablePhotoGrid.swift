import SwiftUI

/// A reusable LazyVGrid that allows the user to select multiple photos by
/// long-pressing and then dragging their finger across cells – behaviour that
/// mirrors Apple Photos' multi-select gesture. The currently highlighted
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
    @State private var isDragging = false
    @State private var dragStartLocation: CGPoint = .zero
    @State private var lastDragLocation: CGPoint = .zero
    @State private var initialSelection: Set<Photo> = []
    @State private var dragStartTime: Date = Date()
    @State private var hasMovedEnoughToSelect = false

    // Grid configuration
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DeviceInfo.shared.screenSize.gridSpacing), count: DeviceInfo.shared.screenSize.gridColumns)
    }
    private var spacing: CGFloat { DeviceInfo.shared.screenSize.gridSpacing }
    
    // Gesture recognition constants
    private let minimumDragDistance: CGFloat = 30 // Higher threshold for better scroll/drag separation
    private let minimumDragDelay: TimeInterval = 0.2 // 200ms delay before selection starts
    private let longPressThreshold: TimeInterval = 0.4 // Longer press for better recognition

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
                    .onLongPressGesture(minimumDuration: longPressThreshold) {
                        // Enter selection mode & select initial photo
                        if !isSelecting {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSelecting = true
                                selected = Set([photo])
                                initialSelection = Set([photo])
                            }
                            // Haptic feedback
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
            }
            .padding(spacing)
            // Coordinate space is needed to translate global drag coordinates into
            // the grid's local space when checking which frame contains the point.
            .coordinateSpace(name: "photoGrid")
            // Only apply drag gesture when in selection mode
            .gesture(isSelecting ? selectionDragGesture : nil)
        }
        // Collect cell frames via a preference key so we can hit-test during the drag
        .onPreferenceChange(PhotoFramePreferenceKey.self) { value in
            cellFrames = value
        }
        // Exit selection mode when it's turned off
        .onChange(of: isSelecting) { _, newValue in
            if !newValue {
                resetDragState()
            }
        }
    }

    // MARK: – Drag Gesture with improved recognition
    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDragDistance)
            .onChanged { value in
                let currentTime = Date()
                
                if !isDragging {
                    // Starting a new drag selection
                    dragStartTime = currentTime
                    dragStartLocation = value.startLocation
                    initialSelection = selected
                    hasMovedEnoughToSelect = false
                }
                
                // Check if enough time has passed and we've moved enough
                let timePassed = currentTime.timeIntervalSince(dragStartTime)
                let distanceMoved = sqrt(pow(value.location.x - dragStartLocation.x, 2) + 
                                       pow(value.location.y - dragStartLocation.y, 2))
                
                if timePassed >= minimumDragDelay && distanceMoved >= minimumDragDistance {
                    if !isDragging {
                        isDragging = true
                        hasMovedEnoughToSelect = true
                        // Light haptic feedback when selection starts
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    
                    // Update selection based on drag path
                    updateSelectionForDrag(from: dragStartLocation, to: value.location)
                }
                
                lastDragLocation = value.location
            }
            .onEnded { _ in
                // Only process if we actually started dragging
                if isDragging && hasMovedEnoughToSelect {
                    // Selection is already updated, just clean up
                }
                resetDragState()
            }
    }
    
    private func resetDragState() {
        isDragging = false
        dragStartLocation = .zero
        lastDragLocation = .zero
        initialSelection = []
        hasMovedEnoughToSelect = false
        dragStartTime = Date()
    }

    private func updateSelectionForDrag(from startPoint: CGPoint, to endPoint: CGPoint) {
        // Create a rectangle from start to end point
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)
        let selectionRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        
        // Start with initial selection
        var newSelection = initialSelection
        
        // Add all photos whose frames intersect with the selection rectangle
        for (id, frame) in cellFrames {
            if selectionRect.intersects(frame) {
                if let photo = photos.first(where: { $0.id == id }) {
                    newSelection.insert(photo)
                }
            }
        }
        
        // Update selection with animation
        withAnimation(.easeInOut(duration: 0.1)) {
            selected = newSelection
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