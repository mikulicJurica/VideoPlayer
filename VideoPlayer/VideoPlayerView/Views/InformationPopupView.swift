import SwiftUI

// View for displaying Information Popups
struct InformationPopupView: View {
    
    let progress: CGFloat
    let currentPopupPick: CGFloat?
    let isDragging: Bool
    let isFullScreen: Bool
    let playerSize: CGSize
    let infoPopup: InfoPopup
    
    private var progressAroundSpot: Bool {
        (progress > infoPopup.progressSpot - aroundProgressValue) &&
        (progress < infoPopup.progressSpot + aroundProgressValue)
    }
    
    private var shouldShow: Bool {
        (progressAroundSpot && currentPopupPick == nil) ||
        (currentPopupPick == infoPopup.progressSpot && !isDragging)
    }
    
    private var horizontalOffset: CGFloat {
        infoPopup.progressSpot *
        (playerSize.width - Layout.viewWidth - Layout.endHorizontalOffset) +
        Layout.startHorizontalOffset
    }
    
    private var verticalOffset: CGFloat {
        Layout.bottomOffset(isFullScreen) +
        (isDragging && progressAroundSpot ? Layout.draggingVerticalOffset : .zero)
    }
    
    private let aroundProgressValue: CGFloat = 0.005
    
    var body: some View {
        if shouldShow {
            Text(infoPopup.information)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(infoPopup.appearanceColor)
                .frame(maxWidth: Layout.viewWidth)
                .padding(.all, Layout.textPadding)
                .background(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .fill(Color.black.opacity(Layout.backgroundOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .stroke(Color.white, lineWidth: Layout.borderLineWidth)
                )
                .offset(x: horizontalOffset, y: verticalOffset)
        }
    }
}

private extension InformationPopupView {
    
    enum Layout {
        static let viewWidth: CGFloat = 300
        static let textPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 15
        static let borderLineWidth: CGFloat = 2
        static let backgroundOpacity: CGFloat = 0.7
        static let startHorizontalOffset: CGFloat = 10
        static let endHorizontalOffset: CGFloat = 40
        static let draggingVerticalOffset: CGFloat = -130
        
        static func bottomOffset(_ isFullScreen: Bool) -> CGFloat {
            isFullScreen ? -60 : -30
        }
    }
}

