import SwiftUI
import AVKit

// View that shows Current frame on a certain time spot
struct SeekerThumbnailView: View {
    
    let progress: CGFloat
    let draggingImage: UIImage?
    let isDragging: Bool
    let playerSize: CGSize
    let thumbnailSize: CGSize
    let player: AVPlayer?
    let isFullScreen: Bool
    
    private var currentTimestamp: String {
        guard let currentItem: AVPlayerItem = player?.currentItem else {
            return String()
        }
        return CMTime(
            seconds: progress * currentItem.duration.seconds,
            preferredTimescale: 600
        )
        .toTimeString()
    }
    
    private var frameOffsetX: CGFloat {
        progress *
        (playerSize.width - thumbnailSize.width - Layout.endHorizontalOffset) +
        Layout.startHorizontalOffset
    }
    
    var body: some View {
        ZStack {
            if let draggingImage: UIImage {
                Image(uiImage: draggingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                    .overlay(alignment: .bottom) {
                        Text(currentTimestamp)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .offset(y: Layout.topTimestampOffset)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                            .stroke(Color.white, lineWidth: Layout.borderLineWidth)
                    }
            } else {
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                            .stroke(Color.white, lineWidth: Layout.borderLineWidth)
                    }
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .opacity(isDragging ? 1 : .zero)
        // Moving along side with Gesture
        // Adding Some Padding at Start and End
        .offset(x: frameOffsetX, y: Layout.bottomOffset(isFullScreen))
    }
}

private extension SeekerThumbnailView {
    
    enum Layout {
        static let cornerRadius: CGFloat = 15
        static let borderLineWidth: CGFloat = 2
        static let topTimestampOffset: CGFloat = 25
        static let startHorizontalOffset: CGFloat = 10
        static let endHorizontalOffset: CGFloat = 20
        
        static func bottomOffset(_ isFullScreen: Bool) -> CGFloat {
            isFullScreen ? -75 : -45
        }
    }
}
