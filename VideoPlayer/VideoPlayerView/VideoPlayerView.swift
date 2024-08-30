import SwiftUI

struct VideoPlayerView: View {
    
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        GeometryReader { geometry in
            if viewModel.showVideoPlayer {
                VideoPlayerContentView(
                    viewModel: viewModel,
                    geometrySize: geometry.size
                )
            } else {
                WarningView(message: "Something went wrong")
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Main Content View

private extension VideoPlayerView {
    
    struct VideoPlayerContentView: View {
        
        @ObservedObject var viewModel: VideoPlayerViewModel
        
        let geometrySize: CGSize
        
        var body: some View {
            VStack(spacing: Layout.verticalSpacing) {
                videoPlayer()
                if
                    let videoItem: VideoItem = viewModel.videoItem,
                    !viewModel.isFullScreen
                {
                    eventsListView(videoItem)
                }
            }
        }
        
        @ViewBuilder
        func videoPlayer() -> some View {
            VideoPlayer(player: viewModel.player)
                .modifier(
                    VideoPlayerOverlay(
                        viewModel: viewModel,
                        playerSize: geometrySize
                    )
                )
                .onTapGesture {
                    viewModel.playerControllsAppearance()
                }
                .frame(
                    width: geometrySize.width,
                    height: viewModel.isFullScreen ?
                    geometrySize.height : viewModel.resolution.height(geometrySize.width)
                )
                .onAppear {
                    viewModel.onAppear()
                }
        }
        
        @ViewBuilder
        func eventsListView(_ videoItem: VideoItem) -> some View {
            EventsListView(
                player: viewModel.player,
                isFinishedPlaying: viewModel.isFinishedPlaying,
                videoItem: videoItem) { progressSpot in
                    viewModel.onEndedGesture(newProgress: progressSpot)
                }
                .frame(
                    width: geometrySize.width,
                    height: geometrySize.height - viewModel.resolution.height(geometrySize.width)
                )
        }
    }
}

// MARK: - Video Player Overlay Views

private extension VideoPlayerView {
    
    struct VideoPlayerOverlay: ViewModifier {
        
        @ObservedObject var viewModel: VideoPlayerViewModel
        
        let playerSize: CGSize
        
        func body(content: Content) -> some View {
            content
                .overlay(playerControlsView, alignment: .center)
                .overlay(timeView, alignment: .bottom)
                .overlay(seekerThumbnailView, alignment: .bottomLeading)
                .overlay(videoSeekerView, alignment: .bottom)
                .overlay(informationPopupView, alignment: .bottomLeading)
                .overlay(popupProgressSpotView, alignment: .bottomLeading)
                .overlay(optionsControlView, alignment: .bottomTrailing)
        }
        
        // MARK: - Overlays
        
        var playerControlsView: some View {
            Rectangle()
                .fill(Color.black.opacity(Layout.videoPlayerOpacity))
                .opacity(viewModel.showPlayerControls || viewModel.isDragging ? 1 : .zero)
                .animation(.easeInOut(duration: Layout.animationDuration), value: viewModel.isDragging)
                .overlay {
                    PlayerControls(
                        isPlaying: viewModel.isPlaying,
                        isFinishedPlaying: viewModel.isFinishedPlaying,
                        showPlayerControls: viewModel.showPlayerControls,
                        showForwardControl: viewModel.showForwardControll,
                        isDragging: viewModel.isDragging,
                        playPauseTap: { viewModel.playPauseAction() },
                        goBackwardTap: { viewModel.customSeek(.backward) },
                        goForwardTap: { viewModel.customSeek(.forward) }
                    )
                }
        }
        
        var timeView: some View {
            TimeView(
                player: viewModel.player,
                currentTime: viewModel.currentTime,
                showPlayerControls: viewModel.showPlayerControls,
                isFullScreen: viewModel.isFullScreen
            )
        }
        
        var seekerThumbnailView: some View {
            SeekerThumbnailView(
                progress: viewModel.progress,
                draggingImage: viewModel.draggingImage,
                isDragging: viewModel.isDragging,
                playerSize: playerSize,
                thumbnailSize: viewModel.thumbnailSize,
                player: viewModel.player,
                isFullScreen: viewModel.isFullScreen
            )
        }
        
        var videoSeekerView: some View {
            VideoSeekerView(
                progress: viewModel.progress,
                isDragging: viewModel.isDragging,
                playerSize: playerSize,
                showPlayerControls: viewModel.showPlayerControls,
                isFullScreen: viewModel.isFullScreen,
                isFinishedPlaying: viewModel.isFinishedPlaying,
                dragGesture: viewModel.sliderDragGesture(playerSize: playerSize)) { progressValue in
                    viewModel.onEndedGesture(newProgress: progressValue)
                }
        }
        
        var informationPopupView: some View {
            ZStack {
                if let infoPopups: [InfoPopup] = viewModel.videoItem?.infoPopup {
                    ForEach(infoPopups, id: \.progressSpot) { infoPopup in
                        InformationPopupView(
                            progress: viewModel.progress,
                            currentPopupPick: viewModel.currentPopupPick,
                            isDragging: viewModel.isDragging,
                            isFullScreen: viewModel.isFullScreen,
                            playerSize: playerSize,
                            infoPopup: infoPopup
                        )
                    }
                }
            }
        }
        
        var popupProgressSpotView: some View {
            ZStack {
                if let infoPopups: [InfoPopup] = viewModel.videoItem?.infoPopup {
                    ForEach(infoPopups, id: \.progressSpot) { infoPopup in
                        PopupProgressSpotView(
                            playerSize: playerSize,
                            infoPopup: infoPopup,
                            showPlayerControls: viewModel.showPlayerControls,
                            isFullScreen: viewModel.isFullScreen
                        )
                    }
                }
            }
        }
        
        var optionsControlView: some View {
            OptionsControlView(
                isFullScreen: viewModel.isFullScreen,
                isMutted: viewModel.isMutted,
                showPlayerControls: viewModel.showPlayerControls,
                playbackSpeed: viewModel.playbackSpeed,
                changePlaybackSpeedTap: { viewModel.cyclePlaybackRate() },
                onSoundTap: { viewModel.soundConfig() },
                onFullScreenTap: { viewModel.fullScreenConfig() }
            )
        }
    }
}

// MARK: Layout

private extension VideoPlayerView {
    
    enum Layout {
        static let verticalSpacing: CGFloat = 30
        static let videoPlayerOpacity: CGFloat = 0.4
        static let animationDuration: CGFloat = 0.35
    }
}
