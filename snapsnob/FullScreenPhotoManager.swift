import SwiftUI

class FullScreenPhotoManager: ObservableObject {
    // Photo to show in full screen; when nil, no presentation.
    @Published var selectedPhoto: Photo? = nil
} 