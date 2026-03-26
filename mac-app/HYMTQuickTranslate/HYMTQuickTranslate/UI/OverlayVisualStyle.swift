import AppKit
import SwiftUI

enum OverlayVisualStyle: Equatable {
    case fallback
    case liquidGlass

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
            return Color(nsColor: NSColor.labelColor.withAlphaComponent(0.72))
        }
    }

    var borderColor: Color {
        switch self {
        case .fallback:
            return Color.white.opacity(0.18)
        case .liquidGlass:
            return Color.white.opacity(0.28)
        }
    }

    var shadowColor: Color {
        switch self {
        case .fallback:
            return Color.black.opacity(0.12)
        case .liquidGlass:
            return Color.black.opacity(0.18)
        }
    }
}

struct OverlayBackgroundView: View {
    let visualStyle: OverlayVisualStyle

    var body: some View {
        Group {
            switch visualStyle {
            case .fallback:
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(visualStyle.borderColor, lineWidth: 1)
                    )
            case .liquidGlass:
                if #available(macOS 26, *) {
                    OverlayGlassEffectView()
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(visualStyle.borderColor, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        }
        .shadow(color: visualStyle.shadowColor, radius: 18, y: 10)
    }
}

@available(macOS 26.0, *)
private struct OverlayGlassEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = 32
        view.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.18)
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.style = .regular
        nsView.cornerRadius = 32
        nsView.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.18)
    }
}
