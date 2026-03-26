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
            ProgressView("Translating...")
                .progressViewStyle(.circular)
        case let .confirmLongText(text):
            Text("This clipboard text is longer than the quick-translate limit.")
                .font(.headline)
            Text("Preview:")
                .font(.subheadline)
                .foregroundStyle(visualStyle.secondaryTextColor)
            SelectableTextView(text: text, visualStyle: visualStyle)
                .frame(maxHeight: 160)
            HStack {
                secondaryButton("Cancel") {
                    viewModel.close()
                }
                primaryButton("Translate") {
                    viewModel.confirmLongText()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .result(text):
            Text("Translation")
                .font(.headline)
            SelectableTextView(text: text, visualStyle: visualStyle)
                .frame(maxHeight: 200)
            HStack {
                Spacer()
                primaryButton("Close") {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .error(message):
            Text("Translation failed")
                .font(.headline)
            Text(message)
                .foregroundStyle(visualStyle.secondaryTextColor)
            HStack {
                Spacer()
                primaryButton("Close") {
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
