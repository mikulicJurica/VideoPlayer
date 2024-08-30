import SwiftUI
import AVKit

struct VideoSeekerView<GestureType: Gesture>: View {
    
    let progress: CGFloat
    let isDragging: Bool
    let playerSize: CGSize
    let showPlayerControls: Bool
    let isFullScreen: Bool
    let isFinishedPlaying: Bool
    let dragGesture: GestureType
    let onProgressTap: (CGFloat) -> Void
    
    private var isShown: Bool {
        showPlayerControls || !isFullScreen
    }
    
    private var progressWidth: CGFloat {
        playerSize.width * progress
    }
    
    private var seekerDotScale: CGFloat {
        showPlayerControls || isDragging ? 1 : 0.001
    }
    
    private var dotOffset: CGFloat {
        let limit: CGFloat = playerSize.width - Layout.videoSeekerDotDimension
        return progress < 0.5 ? max(progressOffset, .zero) : min(progressOffset, limit)
    }
    
    private var progressOffset: CGFloat {
        playerSize.width * progress - Layout.videoSeekerDotDimension / 2
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray)
                .offset(y: Layout.bottomOffset(isFullScreen))
            
            Rectangle()
                .fill(Color.red)
                .frame(width: progressWidth)
                .offset(y: Layout.bottomOffset(isFullScreen))
            
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.gray)
                    .hidden()
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        onProgressTap(location.x / geometry.size.width)
                    }
                    .padding(.top, Layout.bottomOffset(isFullScreen) - Layout.touchableHeight)
            }
        }
        .frame(height: Layout.videoSeekerHeight)
        .overlay(alignment: .leading) {
            Circle()
                .fill(.red)
                .frame(
                    width: Layout.videoSeekerDotDimension,
                    height: Layout.videoSeekerDotDimension
                )
                .scaleEffect(seekerDotScale)
                .contentShape(Rectangle())
                .offset(
                    x: dotOffset,
                    y: Layout.bottomOffset(isFullScreen)
                )
                .gesture(dragGesture)
        }
        .opacity(isShown ? 1 : .zero)
        .animation(
            .easeInOut(duration: Layout.animationDuration),
            value: isShown
        )
        .disabled(isFinishedPlaying)
    }
}

private struct Layout {
    
    static let videoSeekerHeight: CGFloat = 5
    static let videoSeekerDotDimension: CGFloat = 25
    static let animationDuration: CGFloat = 0.35
    static let touchableHeight: CGFloat = 10
    
    static func bottomOffset(_ isFullScreen: Bool) -> CGFloat {
        isFullScreen ? -30 : .zero
    }
}
