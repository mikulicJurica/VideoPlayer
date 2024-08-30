import SwiftUI
import WebRTC

// This ViewModel is designed to facilitate a video call using WebRTC and WebSocket for signaling
class VideoCallViewModel: NSObject, ObservableObject {
    
    @Published var wsStatusLabel: String = String()
    @Published var wsStatusColor: Color = .black
    @Published var webRTCStatusLabel: String = "WebRTC: Initialized"
    @Published var webRTCStatusColor: Color = .black
    @Published var webRTCMessageLabel: String = "WebRTCMessage: No Message"
    @Published var likeImage: Image = Image(systemName: "heart")
    
    // Video views
    var localVideoView: UIView {
        webRTCClient.localVideoView()
    }
    
    var remoteVideoView: UIView {
        webRTCClient.remoteVideoView()
    }
    
    // Represents the WebSocket connection used for signaling between peers
    // WebRTC requires signaling to exchange SDP and ICE candidates between clients
    private var webSocketTask: URLSessionWebSocketTask?
    // A timer that attempts to establish the WebSocket connection if it is not already connected
    // In case we will need it
    // private var tryToConnectWebSocket: Timer?
    // Used when custom video capturer (i.e., capturing frames manually) is enabled
    private var cameraSession: CameraSession?
    // You can create video source from CMSampleBuffer :)
    private var useCustomCapturer: Bool = false
    // Used when custom video capturer (i.e., capturing frames manually) is enabled
    private var cameraFilter: CameraFilter?
    
    // Manages the WebRTC functionality such as creating peer connections,
    // managing video streams, and handling data channels
    private let webRTCClient: WebRTCClient
    private let wsStatusMessageBase: String = "WebSocket: "
    private let webRTCStatusMesasgeBase: String = "WebRTC: "
    private let likeStr: String = "Like"
    // The IP address for the WebSocket server
    // MARK: Change this ip address in your case
    private let ipAddress: String
    
    init(webRTCClient: WebRTCClient = WebRTCClient(), ipAddress: String = "192.168.8.101") {
        self.webRTCClient = webRTCClient
        self.ipAddress = ipAddress
        
        super.init()
        
        chechForSimulator()
        webRTCClientSetup()
        cameraSetup()
        setupWebSocketConnection()
    }

    deinit {
        // Invalidate the WebSocket reconnection timer
        // We don't use it
        // tryToConnectWebSocket?.invalidate()
        
        // Cancel the WebSocket task
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        
        // Removing delegates to avoid retain cycles
        webRTCClient.delegate = nil
        cameraSession?.delegate = nil
        
        cameraFilter = nil
    }
}

// MARK: Init functions
private extension VideoCallViewModel {
    
    func chechForSimulator() {
    #if targetEnvironment(simulator)
        // Simulator does not have camera
        useCustomCapturer = false
    #endif
    }
    
    func webRTCClientSetup() {
        webRTCClient.delegate = self
        webRTCClient.setup(
            videoTrack: true,
            audioTrack: true,
            dataChannel: true,
            customFrameCapturer: useCustomCapturer
        )
    }
    
    func cameraSetup() {
        if useCustomCapturer {
            print("Use custom capturer")
            cameraSession = CameraSession()
            cameraSession?.delegate = self
            cameraSession?.setupSession()
            
            cameraFilter = CameraFilter()
        }
    }
    
    func setupWebSocketConnection() {
        guard let url: URL = URL(string: "ws://" + ipAddress + ":8080/") else {
            print("Invalid WebSocket URL")
            
            return
        }
        
        let urlSession: URLSession = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: OperationQueue()
        )
        
        webSocketTask = urlSession.webSocketTask(with: url)
        
        // Connect WebSocket
        webSocketTask?.resume()
        receiveWebSocketMessage()
    }
    
    // Just in case
//    func setupWebSocketConnection() {
//        guard let url: URL = URL(string: "ws://" + ipAddress + ":8080/") else {
//            print("Invalid WebSocket URL")
//
//            return
//        }
//        
//        let urlSession: URLSession = URLSession(
//            configuration: .default,
//            delegate: self,
//            delegateQueue: OperationQueue()
//        )
//        webSocketTask = urlSession.webSocketTask(with: url)
//        
//        tryToConnectWebSocket = Timer.scheduledTimer(
//            withTimeInterval: 1.0,
//            repeats: true
//        ) { [weak self] timer in
//            guard let self = self else {
//                return
//            }
//            if self.webRTCClient.isConnected || self.webSocketTask?.state == .running {
//                return
//            }
//            self.webSocketTask?.resume()
//            self.receiveWebSocketMessage()
//        }
//    }
}

// MARK: - UI Events

extension VideoCallViewModel {
    
    // Starts the WebRTC connection and sends the local SDP offer to the signaling server
    func callButtonTapped() {
        if !webRTCClient.isConnected {
            // Initiating WebRTC connection by creating an offer SDP
            // Calling webRTCClient.connect to start the WebRTC connection process
            webRTCClient.connect(onSuccess: { [weak self] (offerSDP: RTCSessionDescription) -> Void in
                // Once the offer SDP is created,
                // sendSDP is called to send the SDP offer to the remote peer via WebSocket
                self?.sendSDP(sessionDescription: offerSDP)
            })
        }
    }
    
    // Disconnects the WebRTC connection
    func hangupButtonTapped() {
        if webRTCClient.isConnected {
            webRTCClient.disconnect()
        }
        
        // Reconnect the WebSocket if it was disconnected
        if webSocketTask?.state != .running {
            setupWebSocketConnection()
            webSocketTask?.resume()
            receiveWebSocketMessage()
        }
    }
    
    // Sends a text message over the WebRTC data channel
    func sendMessageButtonTapped() {
        let messages: [String] = [
            "Message-1", "Message-2", "Message-3", "Message-4", "Message-5", "Message-6", "Message-7"
        ]
        webRTCClient.sendMessge(message: messages.randomElement() ?? "Message")
    }
    
    // Sends a "heart" over the WebRTC data channel
    func likeButtonTapped() {
        guard let data: Data = likeStr.data(using: String.Encoding.utf8) else {
            print("Error sending heart data")
            
            return
        }
        likeImage = Image(systemName: "heart")
        webRTCClient.sendData(data: data)
    }
    
    // Switches the camera position (front to back or vice versa)
    func localVideoViewTapped() {
        //        if let filter = self.cameraFilter {
        //            filter.changeFilter(filter.filterType.next())
        //        }
        webRTCClient.switchCameraPosition()
    }
    
    func toggleWebSocketState() {
        guard let socketState: URLSessionTask.State = webSocketTask?.state else {
            print("Error fetching WebSocket state")
            
            return
        }
        if socketState == .running {
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
        } else {
            setupWebSocketConnection()
        }
    }
}

// MARK: - WebSocket Methods
private extension VideoCallViewModel {
    
    func receiveWebSocketMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Failed to receive message: \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.wsStatusLabel = (self.wsStatusMessageBase) + "Disconnected"
                    self.wsStatusColor = .red
                }
                
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleWebSocketMessage(text: text)
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    fatalError()
                }
                // Continue receiving messages
                self?.receiveWebSocketMessage()
            }
        }
    }
    
    func handleWebSocketMessage(text: String) {
        guard let data: Data = text.data(using: .utf8) else {
            print("Error with Web Socket Message Data")
            
            return
        }
        
        do {
            let signalingMessage: SignalingMessage = try JSONDecoder().decode(SignalingMessage.self, from: data)
            
            if signalingMessage.type == "offer" {
                webRTCClient.receiveOffer(
                    offerSDP: RTCSessionDescription(
                        type: .offer,
                        sdp: signalingMessage.sessionDescription?.sdp ?? ""
                    ),
                    onCreateAnswer: { [weak self] answerSDP in
                        self?.sendSDP(sessionDescription: answerSDP)
                    }
                )
            } else if signalingMessage.type == "answer" {
                webRTCClient.receiveAnswer(
                    answerSDP: RTCSessionDescription(
                        type: .answer,
                        sdp: signalingMessage.sessionDescription?.sdp ?? ""
                    )
                )
            } else if signalingMessage.type == "candidate" {
                if let candidate: Candidate = signalingMessage.candidate {
                    webRTCClient.receiveCandidate(
                        candidate: RTCIceCandidate(
                            sdp: candidate.sdp,
                            sdpMLineIndex: candidate.sdpMLineIndex,
                            sdpMid: candidate.sdpMid
                        )
                    )
                } else {
                    print("Failed to get ICE candidate from signaling message.")
                }
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension VideoCallViewModel: URLSessionWebSocketDelegate {
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("-- Websocket did connect --")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.wsStatusLabel = self.wsStatusMessageBase + "Connected"
            self.wsStatusColor = .green
        }
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        print("-- Websocket did disconnect --")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.wsStatusLabel = self.wsStatusMessageBase + "Disconnected"
            self.wsStatusColor = .red
        }
    }
}

// MARK: - WebRTC Signaling
private extension VideoCallViewModel {
    // Sends the SDP (Session Description Protocol) offer or answer via the WebSocket
    // This is essential for establishing a WebRTC connection
    func sendSDP(sessionDescription: RTCSessionDescription) {
        let type: String = sessionDescription.type == .offer ? "offer" : "answer"
        let sdp: SDP = SDP(sdp: sessionDescription.sdp)
        let signalingMessage: SignalingMessage = SignalingMessage(type: type, sessionDescription: sdp, candidate: nil)
        
        do {
            let data: Data = try JSONEncoder().encode(signalingMessage)
            if let message: String = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(message)) { error in
                    if let error: any Error {
                        print("Failed to send candidate: \(error)")
                    }
                }
            } else {
                print("Failed to convert data to UTF-8 string")
            }
        } catch {
            print("Failed to encode message: \(error)")
        }
    }
    
    // Sends ICE candidates (used to find the best path between peers) via the WebSocket
    func sendCandidate(iceCandidate: RTCIceCandidate) {
        guard let sdpMid: String = iceCandidate.sdpMid else {
            print("Failed to send candidate: sdpMid error")
            
            return
        }
        
        let candidate: Candidate = Candidate(
            sdp: iceCandidate.sdp,
            sdpMLineIndex: iceCandidate.sdpMLineIndex,
            sdpMid: sdpMid
        )
        
        let signalingMessage: SignalingMessage = SignalingMessage(
            type: "candidate",
            sessionDescription: nil,
            candidate: candidate
        )
        
        do {
            let data: Data = try JSONEncoder().encode(signalingMessage)
            if let message: String = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(message)) { error in
                    if let error: any Error {
                        print("Failed to send candidate: \(error)")
                    }
                }
            } else {
                print("Failed to convert data to UTF-8 string")
            }
        } catch {
            print("Failed to encode candidate: \(error)")
        }
    }
}


// MARK: - WebRTCClient Delegate
extension VideoCallViewModel: WebRTCClientDelegate {
    
    // Sends the generated ICE candidate via WebSocket to the remote peer
    func didGenerateCandidate(iceCandidate: RTCIceCandidate) {
        // When a local ICE candidate is generated, it’s sent to the remote peer via sendCandidate
        sendCandidate(iceCandidate: iceCandidate)
    }
    
    // Updates the UI to reflect changes in the WebRTC connection state
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState) {
        var state: String = ""
        
        switch iceConnectionState {
        case .checking:
            state = "Checking..."
        case .closed:
            state = "Closed"
        case .completed:
            state = "Completed"
        case .connected:
            state = "Connected"
        case .count:
            state = "Count..."
        case .disconnected:
            state = "Disconnected"
        case .failed:
            state = "Failed"
        case .new:
            state = "New..."
        @unknown default:
            fatalError()
        }
        webRTCStatusLabel = webRTCStatusMesasgeBase + state
    }
    
    // Confirms the data channel is open and ready for messaging
    func didOpenDataChannel() {
        print("Did open data channel")
    }
    
    // Handles incoming data on the WebRTC data channel (like “like” messages)
    func didReceiveData(data: Data) {
        if data == likeStr.data(using: String.Encoding.utf8) {
            likeImage = Image(systemName: "heart.fill")
        }
    }
    
    // Displays the received message in the UI
    func didReceiveMessage(message: String) {
        webRTCMessageLabel = message
    }
    
    // Indicates that the WebRTC connection is established and disconnects the WebSocket since it’s no longer needed
    // Triggered when the WebRTC connection is successfully established
    func didConnectWebRTC() {
        // Updates the UI to show the connection status and disconnects the WebSocket as it’s no longer needed
        webRTCStatusColor = .green
        // Disconnect websocket - Not needed for this app at the moment
        // self.webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // Indicates that the WebRTC connection has been terminated
    // Triggered when the WebRTC connection is disconnected
    func didDisconnectWebRTC() {
        webRTCStatusColor = .red
    }
}

// MARK: - CameraSessionDelegate
extension VideoCallViewModel: CameraSessionDelegate {
    
    // If a custom video capturer is used, this method captures the current video frame,
    // applies any filters, and sends it to the WebRTC client for streaming
    func didOutput(_ sampleBuffer: CMSampleBuffer) {
        if useCustomCapturer {
            if let cvpixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
                if let buffer: CVPixelBuffer = cameraFilter?.apply(cvpixelBuffer){
                    webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
                } else {
                    print("No applied image")
                }
            } else {
                print("No pixelbuffer")
            }
//            self.webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
        }
    }
}
