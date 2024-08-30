import SwiftUI

struct VideoCallView: View {
    
    @ObservedObject var viewModel: VideoCallViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            videoDisplaySection
            Divider()
            controlSection
        }
    }
    
    private var videoDisplaySection: some View {
        HStack {
            VStack(spacing: .zero) {
                VideoViewRepresentable(view: viewModel.localVideoView)
                    .frame(width: UIScreen.main.bounds.width / 6, height: UIScreen.main.bounds.height / 5)
                    .onTapGesture {
                        viewModel.localVideoViewTapped()
                    }
                Text("Local View")
            }
            VideoViewRepresentable(view: viewModel.remoteVideoView)
                .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height * 0.5)
            Spacer()
        }
    }
    
    private var controlSection: some View {
        VStack(spacing: 10) {
            likeAndGreetButtons
            statusLabels
            callAndHangupButtons
        }
    }
    
    private var likeAndGreetButtons: some View {
        HStack {
            Button(action: {
                viewModel.likeButtonTapped()
            }) {
                viewModel.likeImage
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.red)
            }
            CallActionButton(title: "Send Message", backgroundColor: .green) {
                viewModel.sendMessageButtonTapped()
            }
            
            CallActionButton(title: "Toggle WebSocket - For TESTING", backgroundColor: .yellow) {
                viewModel.toggleWebSocketState()
            }
        }
    }
    
    private var statusLabels: some View {
        VStack(spacing: 5) {
            Text(viewModel.wsStatusLabel)
                .foregroundColor(viewModel.wsStatusColor)
            Text(viewModel.webRTCStatusLabel)
                .foregroundColor(viewModel.webRTCStatusColor)
            Text(viewModel.webRTCMessageLabel)
        }
    }
    
    private var callAndHangupButtons: some View {
        HStack {
            CallActionButton(title: "Call", backgroundColor: .blue) {
                viewModel.callButtonTapped()
            }
            CallActionButton(title: "Hang up", backgroundColor: .red) {
                viewModel.hangupButtonTapped()
            }
        }
    }
}

struct CallActionButton: View {
    
    let title: String
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .padding()
                .background(backgroundColor)
                .cornerRadius(10)
        }
    }
}
