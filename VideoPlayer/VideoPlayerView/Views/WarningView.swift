import SwiftUI

struct WarningView: View {
    
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            
            Text(message)
                .foregroundColor(.red)
                .font(.headline)
        }
        .padding(Layout.viewPadding)
        .background(Color.yellow.opacity(Layout.colorOpacity))
        .cornerRadius(Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(Color.red, lineWidth: Layout.lineWidth)
        )
    }
}

private extension WarningView {
    
    enum Layout {
        static let viewPadding: CGFloat = 15
        static let colorOpacity: CGFloat = 0.2
        static let cornerRadius: CGFloat = 8
        static let lineWidth: CGFloat = 2
    }
}
