import AppKit
import SwiftUI

enum OverlayVisualStyle: Equatable {
    case fallback
    case liquidGlass

    static let cornerRadius: CGFloat = 20

    static func make(isMacOS26OrNewer: Bool) -> OverlayVisualStyle {
        isMacOS26OrNewer ? .liquidGlass : .fallback
    }

    static var current: OverlayVisualStyle {
        if #available(macOS 26, *) {
            return .liquidGlass
        }
        return .fallback
    }

    var secondaryTextColor: Color {
        switch self {
        case .fallback:
            return .secondary
        case .liquidGlass:
            return Color(nsColor: NSColor.labelColor.withAlphaComponent(0.78))
        }
    }

    var prefersClearGlass: Bool {
        switch self {
        case .fallback:
            return false
        case .liquidGlass:
            return true
        }
    }

    var requiresTransparentWindow: Bool {
        switch self {
        case .fallback:
            return false
        case .liquidGlass:
            return true
        }
    }

    var backgroundMaterialOpacity: Double {
        switch self {
        case .fallback:
            return 0.82
        case .liquidGlass:
            return 0.60
        }
    }

    var glassTintOpacity: Double {
        switch self {
        case .fallback:
            return 0.14
        case .liquidGlass:
            return 0.02
        }
    }

    var surfaceFillOpacity: Double {
        switch self {
        case .fallback:
            return 0.10
        case .liquidGlass:
            return 0.06
        }
    }

    var edgeHighlightOpacity: Double {
        switch self {
        case .fallback:
            return 0.16
        case .liquidGlass:
            return 0.24
        }
    }

    var edgeShadowOpacity: Double {
        switch self {
        case .fallback:
            return 0.08
        case .liquidGlass:
            return 0.12
        }
    }

    func adaptiveReadabilityOpacity(for averageLuminance: CGFloat?) -> Double {
        switch self {
        case .fallback:
            return 0.0
        case .liquidGlass:
            guard let averageLuminance else {
                return 0.16
            }

            let clampedLuminance = min(max(Double(averageLuminance), 0.0), 1.0)
            let mappedOpacity = 0.3026 - (0.2714 * clampedLuminance)
            return min(max(mappedOpacity, 0.08), 0.28)
        }
    }

    var contentSurfaceOpacity: Double {
        switch self {
        case .fallback:
            return 0.0
        case .liquidGlass:
            return 0.0
        }
    }

    var contentBorderOpacity: Double {
        switch self {
        case .fallback:
            return 0.0
        case .liquidGlass:
            return 0.0
        }
    }

    var contentCornerRadius: CGFloat {
        switch self {
        case .fallback:
            return 14
        case .liquidGlass:
            return 14
        }
    }

    var borderColor: Color {
        switch self {
        case .fallback:
            return Color.white.opacity(0.14)
        case .liquidGlass:
            return Color.white.opacity(0.18)
        }
    }

    var shadowColor: Color {
        switch self {
        case .fallback:
            return Color.black.opacity(0.1)
        case .liquidGlass:
            return Color.black.opacity(0.14)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .fallback:
            return 18
        case .liquidGlass:
            return 24
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .fallback:
            return 10
        case .liquidGlass:
            return 14
        }
    }
}

struct OverlayBackgroundView: View {
    let visualStyle: OverlayVisualStyle
    let averageLuminance: CGFloat?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OverlayVisualStyle.cornerRadius, style: .continuous)
    }

    private var readabilityOpacity: Double {
        visualStyle.adaptiveReadabilityOpacity(for: averageLuminance)
    }

    var body: some View {
        ZStack {
            if visualStyle == .liquidGlass, #available(macOS 26, *) {
                OverlayGlassEffectView(
                    prefersClearGlass: visualStyle.prefersClearGlass,
                    tintOpacity: visualStyle.glassTintOpacity
                )
            }

            shape
                .fill(.ultraThinMaterial)
                .opacity(visualStyle.backgroundMaterialOpacity)

            shape
                .fill(Color.white.opacity(visualStyle.surfaceFillOpacity))

            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(readabilityOpacity),
                            Color.white.opacity(readabilityOpacity * 0.58),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 280
                    )
                )
                .blendMode(.screen)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(visualStyle.edgeHighlightOpacity),
                            Color.white.opacity(visualStyle.edgeHighlightOpacity * 0.35),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(shape.stroke(lineWidth: 1.6))
                .blendMode(.screen)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(visualStyle.edgeShadowOpacity),
                            Color.clear
                        ],
                        startPoint: .bottomTrailing,
                        endPoint: .center
                    )
                )
                .mask(shape.stroke(lineWidth: 1.1))
                .blendMode(.multiply)

            shape
                .stroke(visualStyle.borderColor, lineWidth: 1)
        }
        .compositingGroup()
        .shadow(
            color: visualStyle.shadowColor,
            radius: visualStyle.shadowRadius,
            y: visualStyle.shadowYOffset
        )
    }
}

@available(macOS 26.0, *)
private struct OverlayGlassEffectView: NSViewRepresentable {
    let prefersClearGlass: Bool
    let tintOpacity: Double

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = prefersClearGlass ? .clear : .regular
        view.cornerRadius = OverlayVisualStyle.cornerRadius
        view.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(tintOpacity)
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.style = prefersClearGlass ? .clear : .regular
        nsView.cornerRadius = OverlayVisualStyle.cornerRadius
        nsView.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(tintOpacity)
    }
}
