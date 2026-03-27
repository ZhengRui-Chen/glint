import SwiftUI

struct ShortcutPanelView: View {
    @ObservedObject var state: ShortcutPanelViewState

    let onStartSelectionRecording: () -> Void
    let onStartClipboardRecording: () -> Void
    let onResetToDefaults: () -> Void
    let onDone: () -> Void

    private let visualStyle = OverlayVisualStyle.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(spacing: 12) {
                shortcutRow(
                    title: "Translate Selection",
                    shortcut: state.selectionShortcutLabel,
                    isRecording: state.isRecordingSelectionShortcut,
                    action: onStartSelectionRecording
                )
                shortcutRow(
                    title: "Translate Clipboard",
                    shortcut: state.clipboardShortcutLabel,
                    isRecording: state.isRecordingClipboardShortcut,
                    action: onStartClipboardRecording
                )
            }

            statusBlock

            HStack(spacing: 12) {
                Button("Reset to Defaults", action: onResetToDefaults)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 440)
        .background(
            OverlayBackgroundView(
                visualStyle: visualStyle,
                averageLuminance: nil
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: OverlayVisualStyle.cornerRadius, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: state.statusMessage)
        .animation(.easeOut(duration: 0.18), value: state.recordingTarget)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Keyboard Shortcuts")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
            Text("Set shortcuts for selection and clipboard translation.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(visualStyle.secondaryTextColor)
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(statusForegroundColor)
                .id(statusText)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .padding(.top, 2)
    }

    private var statusText: String {
        state.statusMessage ?? "Choose a shortcut to edit."
    }

    private var statusForegroundColor: Color {
        if state.statusMessage == nil {
            return visualStyle.secondaryTextColor
        }
        return Color.primary
    }

    @ViewBuilder
    private func shortcutRow(
        title: String,
        shortcut: String,
        isRecording: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Text(isRecording ? "Press keys" : "Click to change")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(visualStyle.secondaryTextColor)
            }

            Spacer(minLength: 12)

            ShortcutRecorderButton(
                shortcut: shortcut,
                isRecording: isRecording,
                action: action
            )
        }
    }
}
