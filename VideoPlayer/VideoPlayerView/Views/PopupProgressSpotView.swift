import SwiftUI

// Spot on Progress Slider that contains Information Popup
struct PopupProgressSpotView: View {
    
    let playerSize: CGSize
    let infoPopup: InfoPopup
    let showPlayerControls: Bool
    let isFullScreen: Bool
    
    private var isShown: Bool {
        showPlayerControls || !isFullScreen
    }
    
    private var horizontalOffset: CGFloat {
        infoPopup.progressSpot * playerSize.width - Layout.progressSpotWidth / 2
    }
    
    private var verticalOffset: CGFloat {
        Layout.progressSpotHeight / 2
    }
    
    var body: some View {
        Rectangle()
            .fill(infoPopup.appearanceColor)
            .frame(
                width: Layout.progressSpotWidth,
                height: Layout.progressSpotHeight
            )
            .offset(
                x: horizontalOffset,
                y: verticalOffset + Layout.bottomOffset(isFullScreen)
            )
            .opacity(isShown ? 1 : .zero)
            .animation(
                .easeInOut(duration: Layout.animationDuration),
                value: isShown
            )
    }
}

private extension PopupProgressSpotView {
    
    enum Layout {
        static let progressSpotWidth: CGFloat = 10
        static let progressSpotHeight: CGFloat = 20
        static let animationDuration: CGFloat = 0.35
        
        static func bottomOffset(_ isFullScreen: Bool) -> CGFloat {
            isFullScreen ? -30 : .zero
        }
    }
}

