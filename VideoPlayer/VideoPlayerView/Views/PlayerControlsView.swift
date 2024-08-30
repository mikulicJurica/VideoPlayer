import SwiftUI

struct PlayerControls: View {
    
    let isPlaying: Bool
    let isFinishedPlaying: Bool
    let showPlayerControls: Bool
    let showForwardControl: Bool
    let isDragging: Bool
    let playPauseTap: () -> Void
    let goBackwardTap: () -> Void
    let goForwardTap: () -> Void
    
    private var shouldShowControls: Bool {
        showPlayerControls && !isDragging
    }
    
    var body: some View {
        HStack(spacing: Layout.horizontalSpacing) {
            ControlButton(imageName: "gobackward.5", action: goBackwardTap)
                .opacity(isFinishedPlaying ? .zero : 1)
            
            ControlButton(
                imageName: isFinishedPlaying ? "arrow.clockwise" : (isPlaying ? "pause.fill" : "play.fill"),
                action: playPauseTap
            )
            .scaleEffect(Layout.mainButtonScale(isFinishedPlaying))
            
            ControlButton(imageName: "goforward.5", action: goForwardTap)
                .opacity(showForwardControl ? 1 : .zero)
        }
        .opacity(shouldShowControls ? 1 : .zero)
        .animation(.easeInOut(duration: Layout.animationDuration), value: shouldShowControls)
    }
}

private extension PlayerControls {
    
    struct ControlButton: View {
        let imageName: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: imageName)
                    .foregroundColor(.white)
                    .padding(Layout.buttonPadding)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(Layout.buttonOpacity)))
            }
        }
    }
}

private extension PlayerControls {
    
    enum Layout {
        static let horizontalSpacing: CGFloat = 25
        static let buttonPadding: CGFloat = 15
        static let buttonOpacity: CGFloat = 0.35
        static let animationDuration: Double = 0.2
        
        static func mainButtonScale(_ enlarge: Bool) -> CGFloat {
            enlarge ? 2 : 1.1
        }
    }
}
