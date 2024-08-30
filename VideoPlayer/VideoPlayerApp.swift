import SwiftUI

@main
struct VideoPlayerApp: App {
    
    let videoData: VideoItem = VideoItem(
        videoPath: "video1",
        videoType: "mp4",
        infoPopup: [
            InfoPopup(
                progressSpot: 0.1,
                information: "First. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
                appearanceColor: .yellow
            ),
            InfoPopup(
                progressSpot: 0.5,
                information: "Second. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
                appearanceColor: .blue
            ),
            InfoPopup(
                progressSpot: 0.7,
                information: "Third. quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",
                appearanceColor: .green
            )
        ]
    )
    
    let sampleVideoUrlString: String = "https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mp4-file.mp4"
    
    var body: some Scene {
        WindowGroup {
            TabView {
                VideoCallView(viewModel: VideoCallViewModel())
                    .tabItem {
                        Label("WebRTC", systemImage: "video")
                    }
                
                VideoPlayerView(viewModel: VideoPlayerViewModel(videoUrlString: sampleVideoUrlString))
//                VideoPlayerView(viewModel: VideoPlayerViewModel(videoItem: videoData))
                    .tabItem {
                        Label("Video Player", systemImage: "play.circle")
                    }
            }
        }
    }
}
