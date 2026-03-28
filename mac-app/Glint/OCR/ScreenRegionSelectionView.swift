import SwiftUI

enum ScreenRegionSelectionLayout {
    static func panelFrames(for screenFrames: [CGRect]) -> [CGRect] {
        screenFrames
    }

    static func localSelectionRect(
        for globalRect: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        let intersection = globalRect.intersection(screenFrame)
        guard intersection.isNull == false,
              intersection.isEmpty == false else {
            return .zero
        }
        return intersection.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    static func displayRect(for rect: CGRect, canvasHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: canvasHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func captureRect(
        forGlobalRect rect: CGRect,
        desktopFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: desktopFrame.maxY - rect.maxY,
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
        return captureRect(forGlobalRect: globalRect, desktopFrame: desktopFrame)
    }
}

struct ScreenRegionSelectionView: View {
    @ObservedObject var model: ScreenRegionSelectionModel
    let screenFrame: CGRect

    var body: some View {
        GeometryReader { proxy in
            let localRect = ScreenRegionSelectionLayout.localSelectionRect(
                for: model.selectionRect,
                screenFrame: screenFrame
            )
            let displayRect = ScreenRegionSelectionLayout.displayRect(
                for: localRect,
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
                    Text(L10n.ocrSelectionTitle)
                        .font(.headline)
                    Text(L10n.ocrSelectionHint)
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
