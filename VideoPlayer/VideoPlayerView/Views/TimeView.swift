import SwiftUI
import AVKit

struct TimeView: View {
    
    let player: AVPlayer?
    let currentTime: CMTime
    let showPlayerControls: Bool
    let isFullScreen: Bool
    
    private var isShown: Bool {
        showPlayerControls || !isFullScreen
    }
    
    var body: some View {
        HStack {
            if let currentItem: AVPlayerItem = player?.currentItem {
                Text(currentTime.toTimeString())
                Spacer()
                Text(
                    CMTime(
                        seconds: currentItem.duration.seconds,
                        preferredTimescale: 600).toTimeString()
                )
            }
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.bottom, Layout.bottomPadding(isFullScreen))
        .padding(.horizontal, Layout.horizontalPadding)
        .opacity(isShown ? 1 : .zero)
        .animation(
            .easeInOut(duration: Layout.animationDuration),
            value: isShown
        )
    }
}

private extension TimeView {
    
    enum Layout {
        static let horizontalPadding: CGFloat = 10
        static let animationDuration: CGFloat = 0.35
        
        static func bottomPadding(_ isFullScreen: Bool) -> CGFloat {
            isFullScreen ? 50 : 20
        }
    }
}
