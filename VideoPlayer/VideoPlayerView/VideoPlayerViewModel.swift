import SwiftUI
import AVKit

class VideoPlayerViewModel: ObservableObject {
    
    var showVideoPlayer: Bool = false
    var progress: CGFloat = .zero
    var isPlaying: Bool = false
    var isFinishedPlaying: Bool = false
    var showForwardControll: Bool = true
    var currentPopupPick: CGFloat?
    var draggingImage: UIImage?
    
    @Published var currentTime: CMTime = .zero
    @Published var showPlayerControls: Bool = true
    @Published var isDragging: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var isMutted: Bool = false
    @Published var playbackSpeed: PlaybackSpeed = .normal
    
    let player: AVPlayer
    let videoItem: VideoItem?
    let resolution: VideoPlayerAspectRatio = .ultrawide
    // Next value should be determined on expected videos duration
    // Lower value is better for memory consumption
    let thumbnailSize: CGSize = CGSize(width: 175, height: 100)
    
    private var timeoutTask: DispatchWorkItem?
    private var thumbnailFrames: [UIImage] = []
    private var lastDraggedProgress: CGFloat = .zero
    private var playerStatusObserver: NSKeyValueObservation?
    private var isObserverAdded: Bool = false
    private var lastSeekTime: Date?
    
    @Published private var isSeeking: Bool = false
    
    private let seekSeconds: Double = 5
    private let timeoutValue: Int = 3
    private let animationDuration: Double = 0.35
    private let seekOffInterval: TimeInterval = 0.3
    // Next value should be determined on expected videos duration
    // 1/0.001 = 100 (Frames) - Number of frames based on slider
    // Higher value is better for memory consumption
    private let frameStrideValue: Double = 0.01
    
    // MARK: Initializers
    
    // Initializer with Local file
    init(videoItem: VideoItem) {
        self.videoItem = videoItem
        
        guard let bundlePath: String = Bundle.main.path(
            forResource: videoItem.videoPath,
            ofType: videoItem.videoType
        ) else {
            // No valid bundle path
            player = AVPlayer()
            showVideoPlayer = false
            
            return
        }
        
        player = AVPlayer(url: URL(filePath: bundlePath))
        showVideoPlayer = true
    }
    
    // Initializer with URL string
    init(videoUrlString: String) {
        self.videoItem = nil
        
        guard
            let url: URL = URL(string: videoUrlString),
            UIApplication.shared.canOpenURL(url)
        else {
            // No valid URL
            player = AVPlayer()
            showVideoPlayer = false
            
            return
        }
        
        player = AVPlayer(url: url)
        showVideoPlayer = true
    }
    
    // MARK: Deinitializer
    
    deinit {
        playerStatusObserver?.invalidate()
        player.pause()
        timeoutTask?.cancel()
        thumbnailFrames.removeAll()
    }
}

// MARK: OnAppear Function

extension VideoPlayerViewModel {
    
    func onAppear() {
        guard !isObserverAdded else {
            return
        }
        
        // Adding Observer to update Seeker when the video is Playing
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            guard let self = self else {
                return
            }
            self.updateVideoProgress(self.player)
        }
        
        isObserverAdded = true
        
        // Before generating Thumbnails, check if the Video is loaded
        playerStatusObserver = player.observe(\.status, options: .new, changeHandler: { [weak self] player, _ in
            if player.status == .readyToPlay && self?.thumbnailFrames.isEmpty == true {
                self?.generateThumbnailFrames()
            }
        })
        
        isMutted = player.volume == .zero
    }
}

// MARK: Drag Gesture Functions

extension VideoPlayerViewModel {
    
    func sliderDragGesture(playerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { [weak self] value in
                self?.onChangedGesture(playerSize: playerSize, value)
                self?.isDragging = true
            }
            .onEnded { [weak self] _ in
                self?.onEndedGesture(newProgress: nil)
                self?.isDragging = false
            }
    }
    
    func onEndedGesture(newProgress: CGFloat?) {
        showPlayerControls = true
        
        if let newProgress: CGFloat {
            progress = newProgress
        }
        
        lastDraggedProgress = progress
        currentPopupPick = nil
        
        // Seeking Video To Dragged Time
        if let currentPlayerItem: AVPlayerItem = player.currentItem {
            let totalDuration: Double = currentPlayerItem.duration.seconds
            
            player.seek(to: .init(seconds: totalDuration * progress, preferredTimescale: 600))
            
            // Re.Scheduling Timeout Task
            if isPlaying {
                timeoutControls()
            }
            
            // Releasing With Slight Delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.isSeeking = false
            }
        }
    }
}

// MARK: Private Drag Gesture Function

extension VideoPlayerViewModel {
    
    func onChangedGesture(playerSize: CGSize, _ value: DragGesture.Value) {
        // Cancelling Existing Timeout Task
        timeoutTask?.cancel()
        
        // Calculating Progress
        let translationX: CGFloat = value.translation.width
        let calculatedProgress: CGFloat = (translationX / playerSize.width) + lastDraggedProgress
        
        progress = max(min(calculatedProgress, 1), .zero)
        isSeeking = true
        
        let dragIndex: Int = Int(progress / frameStrideValue)
        // Checking if FrameThumbnails Contains the Frame
        if thumbnailFrames.indices.contains(dragIndex) {
            draggingImage = thumbnailFrames[dragIndex]
        }
    }
}

// MARK: Player Controll Functions

extension VideoPlayerViewModel {
    
    func playPauseAction() {
        if isFinishedPlaying {
            isFinishedPlaying = false
            player.seek(to: .zero)
            progress = .zero
            lastDraggedProgress = .zero
        }
        
        if isPlaying {
            player.pause()
            timeoutTask?.cancel()
        } else {
            player.play()
            timeoutControls()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else {
                    return
                }
                player.rate = self.playbackSpeed.rawValue
            }
        }
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            isPlaying.toggle()
        }
    }
    
    func customSeek(_ seek: VideoSeek) {
        let currentSeekTime: Date = Date()
        
        // Seek Off Interval is added to disable frequent function calls
        // With this CPU usage spikes are reduced to a minimum
        if
            let lastSeekTime = lastSeekTime,
            currentSeekTime.timeIntervalSince(lastSeekTime) < seekOffInterval
        {
            return
        }
        lastSeekTime = currentSeekTime
        
        guard let currentPlayerItem: AVPlayerItem = player.currentItem else {
            return
        }
        
        timeoutControls()
        
        let seconds: Double = seek == .forward ? seekSeconds : -seekSeconds
        let currentTime: CMTime = player.currentTime()
        let seekTime: CMTime = CMTime(seconds: seconds, preferredTimescale: currentTime.timescale)
        let newTime: CMTime = CMTimeAdd(currentTime, seekTime)
        
        if CMTimeCompare(newTime, currentPlayerItem.duration) < .zero {
            player.seek(to: newTime)
        }
    }
    
    func playerControllsAppearance() {
        withAnimation(.easeOut(duration: animationDuration)) {
            showPlayerControls.toggle()
            currentPopupPick = nil
        }
        
        // Timing Out Controls, Only If the Video is Playing
        if isPlaying {
            timeoutControls()
        }
    }
}

// MARK: Option Controls Functions

extension VideoPlayerViewModel {
    
    func soundConfig() {
        isMutted.toggle()
        player.volume = isMutted ? .zero : 1
        timeoutControls()
    }
    
    func fullScreenConfig() {
        isFullScreen.toggle()
        timeoutControls()
    }
    
    func cyclePlaybackRate() {
        let allRates: [PlaybackSpeed] = PlaybackSpeed.allCases
        
        guard let currentIndex: Array<PlaybackSpeed>.Index = allRates.firstIndex(of: playbackSpeed) else {
            return
        }
        
        let nextIndex: Int = (currentIndex + 1) % allRates.count
        playbackSpeed = allRates[nextIndex]
        
        // Rate should be updated only when video is playing
        if isPlaying {
            player.rate = playbackSpeed.rawValue
        }
        
        timeoutControls()
    }
}

// MARK: Private Helper Functions

private extension VideoPlayerViewModel {
    
    func updateVideoProgress(_ player: AVPlayer) {
        guard let currentPlayerItem: AVPlayerItem = player.currentItem else {
            return
        }
        
        let totalDuration: Double = currentPlayerItem.duration.seconds
        let currentPlayerTime: CMTime = player.currentTime()
        let calculatedProgress: Double = currentPlayerTime.seconds / totalDuration
        let seekTime: CMTime = CMTime(
            seconds: seekSeconds + 1,
            preferredTimescale: currentPlayerTime.timescale
        )
        let newTime: CMTime = CMTimeAdd(currentPlayerTime, seekTime)
        let timeCompare: Int32 = CMTimeCompare(newTime, currentPlayerItem.duration)
        
        showForwardControll = timeCompare < .zero
        
        if !isSeeking {
            progress = calculatedProgress
            lastDraggedProgress = progress
        }
        
        if calculatedProgress >= 1 {
            handleVideoCompletion()
        } else {
            currentTime = player.currentTime()
        }
    }
    
    func handleVideoCompletion() {
        isFinishedPlaying = true
        isPlaying = false
        showPlayerControls = true
    }
    
    // Timing Out PlayBack controls
    func timeoutControls() {
        // Cancelling Already Pending Timeout Task
        if let timeoutTask: DispatchWorkItem {
            timeoutTask.cancel()
        }
        
        timeoutTask = .init(block: { [weak self] in
            guard let self = self else {
                return
            }
            withAnimation(.easeInOut(duration: self.animationDuration)) {
                self.showPlayerControls = false
            }
        })
        
        // Scheduling Task
        if let timeoutTask: DispatchWorkItem {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .seconds(timeoutValue),
                execute: timeoutTask
            )
        }
    }
    
    // Generating Thumbnail Frames
    func generateThumbnailFrames() {
        Task.detached { [weak self] in
            guard
                let self = self,
                let asset: AVAsset = self.player.currentItem?.asset
            else {
                return
            }
            
            let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = self.thumbnailSize
            
            do {
                let totalDuration: Double = try await asset.load(.duration).seconds
                var frameTimes: [CMTime] = []
                // Frame Timings
                for progress in stride(from: .zero, to: 1, by: self.frameStrideValue) {
                    let time: CMTime = CMTime(seconds: progress * totalDuration, preferredTimescale: 600)
                    frameTimes.append(time)
                }
                
                // Generating Frame Images
                for await result in generator.images(for: frameTimes) {
                    let cgImage: CGImage = try result.image
                    // Adding Frame Image
                    await MainActor.run {
                        self.thumbnailFrames.append(UIImage(cgImage: cgImage))
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

//let memorySize = thumbnailFrames.reduce(0) { (total, image) -> Int in
//    guard let cgImage = image.cgImage else { return total }
//    let bytesPerPixel = cgImage.bitsPerPixel / 8
//    let bytesPerRow = cgImage.bytesPerRow
//    let imageSize = bytesPerRow * cgImage.height
//    return total + imageSize
//}
//
//print("MyLOG: ThumbnailFrames memory size: \(memorySize / 1024) KB")
