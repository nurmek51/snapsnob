import SwiftUI

class FullScreenPhotoManager: ObservableObject {
    // Photo to show in full screen; when nil, no presentation.
    // Selected single photo for fullscreen presentation. When nil, nothing is shown.
    @Published var selectedPhoto: Photo? = nil

    // Selected photo series for story-style presentation. When nil, story view is not shown.
    @Published var selectedSeries: PhotoSeriesData? = nil
} 