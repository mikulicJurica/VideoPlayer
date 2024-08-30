import SwiftUI

struct OptionsControlView: View {
    
    let isFullScreen: Bool
    let isMutted: Bool
    let showPlayerControls: Bool
    let playbackSpeed: PlaybackSpeed
    let changePlaybackSpeedTap: () -> Void
    let onSoundTap: () -> Void
    let onFullScreenTap: () -> Void
    
    var body: some View {
        VStack(spacing: Layout.verticalSpacing) {
            Button {
                withAnimation(.easeOut(duration: Layout.animationDuration)) {
                    changePlaybackSpeedTap()
                }
            } label: {
                ZStack {
                    Text("0.00x")
                        .hidden()
                    
                    Text(String(playbackSpeed.rawValue) + "x")
                        .foregroundColor(.white)
                        .background {
                            Circle()
                                .fill(.black.opacity(Layout.buttonOpacity))
                                .padding(.all, Layout.buttonPadding)
                        }
                }
            }
            
            Button {
                withAnimation(.easeOut(duration: Layout.animationDuration)) {
                    onSoundTap()
                }
            } label: {
                Image(systemName: isMutted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .foregroundColor(.white)
                    .background {
                        Circle()
                            .fill(.black.opacity(Layout.buttonOpacity))
                            .padding(.all, Layout.buttonPadding)
                    }
            }
            
            Button {
                withAnimation(.easeOut(duration: Layout.animationDuration)) {
                    onFullScreenTap()
                }
            } label: {
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .foregroundColor(.white)
                    .background {
                        Circle()
                            .fill(.black.opacity(Layout.buttonOpacity))
                            .padding(.all, Layout.buttonPadding)
                    }
            }
        }
        .opacity(showPlayerControls ? 1 : .zero)
        .animation(
            .easeInOut(duration: Layout.animationDuration),
            value: showPlayerControls
        )
        .padding(.trailing, Layout.trailingPadding)
        .padding(.bottom, Layout.bottomPadding(isFullScreen))
    }
}

private extension OptionsControlView {
    
    enum Layout {
        static let verticalSpacing: CGFloat = 25
        static let animationDuration: CGFloat = 0.35
        static let buttonOpacity: CGFloat = 0.35
        static let buttonPadding: CGFloat = -10
        static let trailingPadding: CGFloat = 10
        static let bottomPadding: CGFloat = 55
        
        static func bottomPadding(_ isFullScreen: Bool) -> CGFloat {
            isFullScreen ? 85 : 55
        }
    }
}
