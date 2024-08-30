import Foundation
import WebRTC

protocol WebRTCClientDelegate {
    func didGenerateCandidate(iceCandidate: RTCIceCandidate)
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState)
    func didOpenDataChannel()
    func didReceiveData(data: Data)
    func didReceiveMessage(message: String)
    func didConnectWebRTC()
    func didDisconnectWebRTC()
}

class WebRTCClient: NSObject, RTCPeerConnectionDelegate, RTCVideoViewDelegate, RTCDataChannelDelegate {
    
    var delegate: WebRTCClientDelegate?
    
    public private(set) var isConnected: Bool = false
    
    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var localRenderView: RTCEAGLVideoView?
    private var localView: UIView?
    private var remoteRenderView: RTCEAGLVideoView?
    private var remoteView: UIView?
    private var remoteStream: RTCMediaStream?
    private var dataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    private var channels: (video: Bool, audio: Bool, datachannel: Bool) = (false, false, false)
    private var customFrameCapturer: Bool = false
    private var cameraDevicePosition: AVCaptureDevice.Position = .front
    
    func localVideoView() -> UIView {
        localView ?? UIView()
    }
    
    func remoteVideoView() -> UIView {
        remoteView ?? UIView()
    }
    
    override init() {
        super.init()
        print("WebRTC Client Initialize")
    }
    
    deinit {
        print("WebRTC Client Deinit")
        peerConnectionFactory = nil
        peerConnection = nil
    }
}

// MARK: - Public functions
extension WebRTCClient {
    
    func setup(videoTrack: Bool, audioTrack: Bool, dataChannel: Bool, customFrameCapturer: Bool) {
        print("Set up")
        
        channels.video = videoTrack
        channels.audio = audioTrack
        channels.datachannel = dataChannel
        self.customFrameCapturer = customFrameCapturer
        
        var videoEncoderFactory: RTCDefaultVideoEncoderFactory = RTCDefaultVideoEncoderFactory()
        var videoDecoderFactory: RTCDefaultVideoDecoderFactory = RTCDefaultVideoDecoderFactory()
        
        if TARGET_OS_SIMULATOR != 0 {
            print("Setup vp8 codec")
            videoEncoderFactory = RTCSimluatorVideoEncoderFactory()
            videoDecoderFactory = RTCSimulatorVideoDecoderFactory()
        }
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
        
        setupView()
        setupLocalTracks()
        
        if
            let localRenderView: RTCEAGLVideoView,
            channels.video
        {
            startCaptureLocalVideo(
                cameraPositon: cameraDevicePosition,
                videoWidth: 640,
                videoHeight: 640 * 16 / 9,
                videoFps: 30
            )
            localVideoTrack?.add(localRenderView)
        }
    }
    
    func setupLocalViewFrame(frame: CGRect) {
        guard
            let localView: UIView,
            let localRenderView: RTCEAGLVideoView
        else {
            print("Error with LocalViewFrame setup")
            
            return
        }
        localView.frame = frame
        localRenderView.frame = localView.frame
    }
    
    func setupRemoteViewFrame(frame: CGRect) {
        guard
            let remoteView: UIView,
            let remoteRenderView: RTCEAGLVideoView
        else {
            print("Error with RemoteViewFrame setup")
            
            return
        }
        remoteView.frame = frame
        remoteRenderView.frame = remoteView.frame
    }
    
    func switchCameraPosition() {
        if let capturer: RTCCameraVideoCapturer = videoCapturer as? RTCCameraVideoCapturer {
            capturer.stopCapture { [weak self] in
                let position: AVCaptureDevice.Position =
                self?.cameraDevicePosition == .front ? AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
                self?.cameraDevicePosition = position
                self?.startCaptureLocalVideo(
                    cameraPositon: position,
                    videoWidth: 640,
                    videoHeight: 640 * 16 / 9,
                    videoFps: 30
                )
            }
        }
    }
    
    // MARK: Connect
    func connect(onSuccess: @escaping (RTCSessionDescription) -> Void) {
        peerConnection = setupPeerConnection()
        peerConnection?.delegate = self
        
        if
            let localVideoTrack: RTCVideoTrack,
            channels.video
        {
            peerConnection?.add(localVideoTrack, streamIds: ["stream0"])
        }
        
        if
            let localAudioTrack: RTCAudioTrack,
            channels.audio
        {
            peerConnection?.add(localAudioTrack, streamIds: ["stream0"])
        }
        
        if channels.datachannel {
            dataChannel = setupDataChannel()
            dataChannel?.delegate = self
        }
        
        makeOffer(onSuccess: onSuccess)
    }
    
    // MARK: HangUp
    func disconnect() {
        if peerConnection != nil {
            peerConnection?.close()
        }
    }
    
    // MARK: Signaling Event
    func receiveOffer(offerSDP: RTCSessionDescription, onCreateAnswer: @escaping (RTCSessionDescription) -> Void) {
        if peerConnection == nil {
            print("Offer received, create peerconnection")
            peerConnection = setupPeerConnection()
            peerConnection?.delegate = self
            
            if
                let localVideoTrack: RTCVideoTrack,
                channels.video
            {
                peerConnection?.add(localVideoTrack, streamIds: ["stream-0"])
            }
            if
                let localAudioTrack: RTCAudioTrack,
                channels.audio
            {
                peerConnection?.add(localAudioTrack, streamIds: ["stream-0"])
            }
            
            if channels.datachannel {
                dataChannel = setupDataChannel()
                dataChannel?.delegate = self
            }
            
        }
        
        print("Set remote description")
        peerConnection?.setRemoteDescription(offerSDP) { [weak self] error in
            if let error: any Error {
                print("Failed to set remote offer SDP")
                print(error)
                
                return
            }
            print("Succeed to set remote offer SDP")
            self?.makeAnswer(onCreateAnswer: onCreateAnswer)
        }
    }
    
    func receiveAnswer(answerSDP: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(answerSDP) { error in
            if let error: any Error {
                print("Failed to set remote answer SDP")
                print(error)
                
                return
            }
        }
    }
    
    func receiveCandidate(candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }
    
    // MARK: DataChannel Event
    func sendMessge(message: String) {
        if
            let _dataChannel: RTCDataChannel = remoteDataChannel,
            let data: Data = message.data(using: String.Encoding.utf8)
        {
            if _dataChannel.readyState == .open {
                let buffer: RTCDataBuffer = RTCDataBuffer(
                    data: data,
                    isBinary: false
                )
                _dataChannel.sendData(buffer)
            } else {
                print("Data channel is not ready state")
            }
        } else {
            print("No data channel")
        }
    }
    
    func sendData(data: Data) {
        if let _dataChannel: RTCDataChannel = remoteDataChannel {
            if _dataChannel.readyState == .open {
                let buffer: RTCDataBuffer = RTCDataBuffer(data: data, isBinary: true)
                _dataChannel.sendData(buffer)
            }
        }
    }
    
    func captureCurrentFrame(sampleBuffer: CMSampleBuffer) {
        if let capturer: RTCCustomFrameCapturer = videoCapturer as? RTCCustomFrameCapturer {
            capturer.capture(sampleBuffer)
        }
    }
    
    func captureCurrentFrame(sampleBuffer: CVPixelBuffer) {
        if let capturer: RTCCustomFrameCapturer = videoCapturer as? RTCCustomFrameCapturer {
            capturer.capture(sampleBuffer)
        }
    }
}

// MARK: - PeerConnection Delegeates
extension WebRTCClient {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        var state: String = ""
        
        if stateChanged == .stable{
            state = "stable"
        } else if stateChanged == .closed{
            state = "closed"
        }
        
        print("Signaling state changed: ", state)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        switch newState {
        case .connected, .completed:
            if !isConnected {
                onConnected()
            }
        default:
            if isConnected{
                onDisConnected()
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didIceConnectionStateChanged(iceConnectionState: newState)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Did add stream")
        remoteStream = stream
        
        if
            let track: RTCVideoTrack = stream.videoTracks.first,
            let remoteRenderView: RTCEAGLVideoView
        {
            print("Video track faund")
            track.add(remoteRenderView)
        }
        
        if let audioTrack: RTCAudioTrack = stream.audioTracks.first{
            print("Audio track faund")
            audioTrack.source.volume = 8
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.didGenerateCandidate(iceCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("--- Did remove stream ---")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        remoteDataChannel = dataChannel
        delegate?.didOpenDataChannel()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
}

// MARK: - RTCVideoView Delegate
extension WebRTCClient{
    
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        let isLandScape: Bool = size.width < size.height
        var renderView: RTCEAGLVideoView?
        var parentView: UIView?
        
        if videoView.isEqual(localRenderView) {
            print("Local video size changed")
            renderView = localRenderView
            parentView = localView
        }
        
        if videoView.isEqual(remoteRenderView) {
            print("Remote video size changed to: ", size)
            renderView = remoteRenderView
            parentView = remoteView
        }
        
        guard
            let _renderView: RTCEAGLVideoView = renderView,
            let _parentView: UIView = parentView
        else {
            return
        }
        
        if isLandScape {
            let ratio: CGFloat = size.width / size.height
            _renderView.frame = CGRect(
                x: 0,
                y: 0,
                width: _parentView.frame.height * ratio,
                height: _parentView.frame.height
            )
            _renderView.center.x = _parentView.frame.width/2
        } else {
            let ratio: CGFloat = size.height / size.width
            _renderView.frame = CGRect(
                x: 0,
                y: 0,
                width: _parentView.frame.width,
                height: _parentView.frame.width * ratio
            )
            _renderView.center.y = _parentView.frame.height/2
        }
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCClient {
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        DispatchQueue.main.async { [weak self] in
            if buffer.isBinary {
                self?.delegate?.didReceiveData(data: buffer.data)
            } else {
                if let message: String = String(data: buffer.data, encoding: String.Encoding.utf8) {
                    self?.delegate?.didReceiveMessage(message: message)
                }
            }
        }
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("Data channel did change state")
        switch dataChannel.readyState {
        case .closed:
            print("Closed")
        case .closing:
            print("Closing")
        case .connecting:
            print("Connecting")
        case .open:
            print("Open")
        @unknown default:
            fatalError()
        }
    }
}

// MARK: - Private functions
private extension WebRTCClient {
    
    // MARK: - Setup
    func setupPeerConnection() -> RTCPeerConnection? {
        let rtcConf: RTCConfiguration = RTCConfiguration()
        rtcConf.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        let mediaConstraints: RTCMediaConstraints = RTCMediaConstraints.init(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        return peerConnectionFactory?.peerConnection(with: rtcConf, constraints: mediaConstraints, delegate: nil)
    }
    
    func setupView() {
        // Local
        localRenderView = RTCEAGLVideoView()
        if let localRenderView: RTCEAGLVideoView {
            localRenderView.delegate = self
            localView = UIView()
            localView?.addSubview(localRenderView)
        }
        
        // Remote
        remoteRenderView = RTCEAGLVideoView()
        if let remoteRenderView: RTCEAGLVideoView {
            remoteRenderView.delegate = self
            remoteView = UIView()
            remoteView?.addSubview(remoteRenderView)
        }
    }
    
    //MARK: - Local Media
    func setupLocalTracks() {
        if channels.video == true {
            localVideoTrack = createVideoTrack()
        }
        if channels.audio == true {
            localAudioTrack = createAudioTrack()
        }
    }
    
    func createAudioTrack() -> RTCAudioTrack? {
        guard let peerConnectionFactory: RTCPeerConnectionFactory else {
            return nil
        }
        let audioConstrains: RTCMediaConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let audioSource: RTCAudioSource = peerConnectionFactory.audioSource(with: audioConstrains)
        let audioTrack: RTCAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        
        // audioTrack.source.volume = 10
        return audioTrack
    }
    
    func createVideoTrack() -> RTCVideoTrack? {
        guard let peerConnectionFactory: RTCPeerConnectionFactory else {
            return nil
        }
        
        let videoSource: RTCVideoSource = peerConnectionFactory.videoSource()
        
        if customFrameCapturer {
            videoCapturer = RTCCustomFrameCapturer(delegate: videoSource)
        } else if TARGET_OS_SIMULATOR != 0 {
            print("Now runnnig on simulator...")
            videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        } else {
            videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        }
        let videoTrack: RTCVideoTrack = peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
        
        return videoTrack
    }
    
    func startCaptureLocalVideo(
        cameraPositon: AVCaptureDevice.Position,
        videoWidth: Int, videoHeight: Int?,
        videoFps: Int
    ) {
        if let capturer: RTCCameraVideoCapturer = videoCapturer as? RTCCameraVideoCapturer {
            var targetDevice: AVCaptureDevice?
            var targetFormat: AVCaptureDevice.Format?
            
            // Find target device
            let devicies: [AVCaptureDevice] = RTCCameraVideoCapturer.captureDevices()
            devicies.forEach { device in
                if device.position == cameraPositon{
                    targetDevice = device
                }
            }
            guard let targetDevice: AVCaptureDevice else {
                print("No target device")
                
                return
            }
            // Find target format
            let formats: [AVCaptureDevice.Format] = RTCCameraVideoCapturer.supportedFormats(for: targetDevice)
            formats.forEach { format in
                for _ in format.videoSupportedFrameRateRanges {
                    let description: CMFormatDescription = format.formatDescription as CMFormatDescription
                    let dimensions: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(description)
                    
                    if dimensions.width == videoWidth && dimensions.height == videoHeight ?? 0{
                        targetFormat = format
                    } else if dimensions.width == videoWidth {
                        targetFormat = format
                    }
                }
            }
            
            guard let targetFormat: AVCaptureDevice.Format else {
                print("No target format")
                
                return
            }
            capturer.startCapture(with: targetDevice, format: targetFormat, fps: videoFps)
            
        } else if let capturer: RTCFileVideoCapturer = videoCapturer as? RTCFileVideoCapturer {
            print("Setup file video capturer")
            if let _ = Bundle.main.path( forResource: "video1.mp4", ofType: nil ) {
                print("Faund video1.mp4 file")
                capturer.startCapturing(fromFileNamed: "video1.mp4") { error in
                    print(error)
                }
            } else {
                print("File did not faund")
            }
        }
    }
    
    // MARK: - Local Data
    func setupDataChannel() -> RTCDataChannel? {
        let dataChannelConfig: RTCDataChannelConfiguration = RTCDataChannelConfiguration()
        dataChannelConfig.channelId = 0
        
        let _dataChannel: RTCDataChannel? = peerConnection?.dataChannel(
            forLabel: "dataChannel",
            configuration: dataChannelConfig
        )
        return _dataChannel
    }
    
    // MARK: - Signaling Offer/Answer
    func makeOffer(onSuccess: @escaping (RTCSessionDescription) -> Void) {
        peerConnection?.offer(
            for: RTCMediaConstraints.init(
                mandatoryConstraints: nil,
                optionalConstraints: nil
            )
        ) { [weak self] sdp, error in
            if let error: any Error {
                print("Error with make offer")
                print(error)
                
                return
            }
            
            if let sdp: RTCSessionDescription {
                print("Make offer, created local sdp")
                self?.peerConnection?.setLocalDescription(sdp, completionHandler: { error in
                    if let error: any Error {
                        print("Error with set local offer sdp")
                        print(error)
                        
                        return
                    }
                    print("Succeed to set local offer SDP")
                    onSuccess(sdp)
                })
            }
            
        }
    }
    
    func makeAnswer(onCreateAnswer: @escaping (RTCSessionDescription) -> Void) {
        peerConnection?.answer(
            for: RTCMediaConstraints(
                mandatoryConstraints: nil,
                optionalConstraints: nil
            )
        ) { [weak self] answerSessionDescription, error in
            if let error: any Error {
                print("Failed to create local answer SDP")
                print(error)
                
                return
            }
            
            print("Succeeded in creating local answer SDP")
            if let answerSDP: RTCSessionDescription = answerSessionDescription {
                self?.peerConnection?.setLocalDescription(answerSDP) { error in
                    if let error: any Error {
                        print("Failed to set local answer SDP")
                        print(error)
                        
                        return
                    }

                    print("Succeeded in setting local answer SDP")
                    onCreateAnswer(answerSDP)
                }
            }
        }
    }
    
    // MARK: - Connection Events
    func onConnected() {
        isConnected = true
        
        DispatchQueue.main.async { [weak self] in
            self?.remoteRenderView?.isHidden = false
            self?.delegate?.didConnectWebRTC()
        }
    }
    
    func onDisConnected() {
        isConnected = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            print("--- On disconnected ---")
            
            self.peerConnection?.close()
            self.peerConnection = nil
            self.remoteRenderView?.isHidden = true
            self.dataChannel = nil
            self.delegate?.didDisconnectWebRTC()
        }
    }
}
