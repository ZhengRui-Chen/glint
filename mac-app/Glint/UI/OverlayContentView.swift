import SwiftUI

struct OverlayContentView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject var backdropState: OverlayBackdropState
    private let visualStyle = OverlayVisualStyle.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
                .id(stateTransitionKey)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 460)
        .background(
            OverlayBackgroundView(
                visualStyle: visualStyle,
                averageLuminance: backdropState.averageLuminance
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: OverlayVisualStyle.cornerRadius, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: stateTransitionKey)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView(L10n.translating)
                .progressViewStyle(.circular)
        case let .confirmLongText(text):
            Text(L10n.clipboardLongTextConfirmation)
                .font(.headline)
            Text(L10n.preview)
                .font(.subheadline)
                .foregroundStyle(visualStyle.secondaryTextColor)
            SelectableTextView(text: text, visualStyle: visualStyle)
                .frame(maxHeight: 160)
            HStack {
                secondaryButton(L10n.cancel) {
                    viewModel.close()
                }
                primaryButton(L10n.translate) {
                    viewModel.confirmLongText()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .result(text):
            Text(L10n.translation)
                .font(.headline)
            SelectableTextView(text: text, visualStyle: visualStyle)
                .frame(maxHeight: 200)
            HStack {
                Spacer()
                primaryButton(L10n.close) {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .error(message):
            Text(L10n.translationFailed)
                .font(.headline)
            SelectableTextView(text: message, visualStyle: visualStyle)
                .frame(minHeight: 72, maxHeight: 220)
            HStack {
                Spacer()
                primaryButton(L10n.close) {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var stateTransitionKey: String {
        switch viewModel.state {
        case .loading:
            return "loading"
        case let .confirmLongText(text):
            return "confirm-\(text)"
        case let .result(text):
            return "result-\(text)"
        case let .error(message):
            return "error-\(message)"
        }
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26, *), visualStyle == .liquidGlass {
            Button(title, action: action)
                .buttonStyle(.glassProminent)
        } else {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26, *), visualStyle == .liquidGlass {
            Button(title, action: action)
                .buttonStyle(.glass)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
        }
    }
}
