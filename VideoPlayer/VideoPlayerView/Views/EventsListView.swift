import SwiftUI
import AVKit

struct EventsListView: View {
    
    let player: AVPlayer?
    let isFinishedPlaying: Bool
    let videoItem: VideoItem
    let onTap: (CGFloat) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.verticalSpacing) {
                if let infoPopups: [InfoPopup] = videoItem.infoPopup {
                    ForEach(infoPopups, id: \.progressSpot) { infoPopup in
                        Button {
                            onTap(infoPopup.progressSpot)
                        } label: {
                            HStack(alignment: .center, spacing: Layout.horizontalSpacing) {
                                if let currentItem: AVPlayerItem = player?.currentItem {
                                    Text(
                                        CMTime(
                                            seconds: infoPopup.progressSpot * currentItem.duration.seconds,
                                            preferredTimescale: 600).toTimeString()
                                    )
                                    .font(.headline)
                                    .foregroundColor(infoPopup.appearanceColor)
                                }
                                Text(infoPopup.information)
                                    .font(.headline)
                                    .foregroundColor(infoPopup.appearanceColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.all, Layout.allPadding)
                        .background {
                            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                                .fill(.black)
                                .opacity(Layout.cellOpacity)
                        }
                    }
                }
            }
        }
        .disabled(isFinishedPlaying)
        .padding(.horizontal, Layout.horizontalPadding)
        .scrollIndicators(.hidden)
    }
}

private extension EventsListView {
    
    enum Layout {
        static let verticalSpacing: CGFloat = 20
        static let horizontalSpacing: CGFloat = 20
        static let allPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 15
        static let cellOpacity: CGFloat = 0.8
        static let horizontalPadding: CGFloat = 10
    }
}
