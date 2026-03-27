import SwiftUI

struct ShortcutRecorderButton: View {
    let shortcut: String
    let isRecording: Bool
    let action: () -> Void

    private let visualStyle = OverlayVisualStyle.current

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(shortcut)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(minWidth: 168)
            .background(backgroundFill)
            .overlay(borderStroke)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(ShortcutRecorderButtonStyle(isRecording: isRecording))
        .animation(.easeOut(duration: 0.18), value: isRecording)
    }

    private var foregroundColor: Color {
        isRecording ? .accentColor : visualStyle.secondaryTextColor
    }

    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isRecording ? Color.accentColor.opacity(0.20) : Color.white.opacity(0.11),
                        isRecording ? Color.accentColor.opacity(0.10) : Color.white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                isRecording ? Color.accentColor.opacity(0.34) : Color.white.opacity(0.14),
                lineWidth: 1
            )
    }
}

private struct ShortcutRecorderButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .shadow(
                color: isRecording ? Color.accentColor.opacity(0.10) : Color.clear,
                radius: 10,
                y: 4
            )
    }
}
