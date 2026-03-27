import SwiftUI

struct ShortcutPanelView: View {
    @ObservedObject var state: ShortcutPanelViewState

    let onStartSelectionRecording: () -> Void
    let onStartClipboardRecording: () -> Void
    let onStartOCRRecording: () -> Void
    let onResetToDefaults: () -> Void
    let onDone: () -> Void

    private let visualStyle = OverlayVisualStyle.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(spacing: 12) {
                shortcutRow(
                    title: L10n.translateSelection,
                    shortcut: state.selectionShortcutLabel,
                    isRecording: state.isRecordingSelectionShortcut,
                    action: onStartSelectionRecording
                )
                shortcutRow(
                    title: L10n.translateClipboard,
                    shortcut: state.clipboardShortcutLabel,
                    isRecording: state.isRecordingClipboardShortcut,
                    action: onStartClipboardRecording
                )
                shortcutRow(
                    title: L10n.translateOCRArea,
                    shortcut: state.ocrShortcutLabel,
                    isRecording: state.isRecordingOCRShortcut,
                    action: onStartOCRRecording
                )
            }

            statusBlock

            HStack(spacing: 12) {
                Button(L10n.resetToDefaults, action: onResetToDefaults)
                    .buttonStyle(.bordered)
                Spacer()
                Button(L10n.done, action: onDone)
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
            Text(L10n.keyboardShortcutsTitle)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
            Text(L10n.shortcutPanelSubtitle)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(visualStyle.secondaryTextColor)
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(statusForegroundColor)
                .id(statusText)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .padding(.top, 2)
    }

    private var statusText: String {
        state.statusMessage ?? L10n.chooseShortcutToEdit
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
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                Text(isRecording ? L10n.pressKeys : L10n.clickToChange)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
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
