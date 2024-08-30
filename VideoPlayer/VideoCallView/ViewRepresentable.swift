import SwiftUI

// Representable for the local video view
struct VideoViewRepresentable: UIViewRepresentable {
    var view: UIView
    
    func makeUIView(context: Context) -> UIView {
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
