import SwiftUI

enum ScreenRegionSelectionLayout {
    static func displayRect(for rect: CGRect, canvasHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: canvasHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func captureRect(
        for rect: CGRect,
        panelFrame: CGRect,
        desktopFrame: CGRect
    ) -> CGRect {
        let globalRect = rect.offsetBy(dx: panelFrame.minX, dy: panelFrame.minY)
        return CGRect(
            x: globalRect.minX,
            y: desktopFrame.maxY - globalRect.maxY,
            width: globalRect.width,
            height: globalRect.height
        )
    }
}

struct ScreenRegionSelectionView: View {
    @ObservedObject var model: ScreenRegionSelectionModel

    var body: some View {
        GeometryReader { proxy in
            let displayRect = ScreenRegionSelectionLayout.displayRect(
                for: model.selectionRect,
                canvasHeight: proxy.size.height
            )

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.18)

                if displayRect.isEmpty == false {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 10)
                        .frame(
                            width: displayRect.width,
                            height: displayRect.height
                        )
                        .offset(x: displayRect.minX, y: displayRect.minY)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("OCR Selection")
                        .font(.headline)
                    Text("Drag to capture an area. Press Esc to cancel.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(24)
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.12), value: model.selectionRect)
    }
}
