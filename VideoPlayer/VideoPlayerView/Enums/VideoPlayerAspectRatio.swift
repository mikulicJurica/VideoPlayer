import Foundation

enum VideoPlayerAspectRatio {
    case sdResolution
    case hdResolution
    case cinema
    case ultrawide
    case cinemascope
    case anamorphic
    
    func height(_ width: CGFloat) -> CGFloat {
        switch self {
        case .sdResolution:
            width / (4 / 3)
        case .hdResolution:
            width / (16 / 9)
        case .cinema:
            width / 1.85
        case .ultrawide:
            width / (21 / 9)
        case .cinemascope:
            width / 2.35
        case .anamorphic:
            width / 2.39
        }
    }
}
