import SwiftUI

struct OverlayContentView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
                .id(stateTransitionKey)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
        .padding(20)
        .frame(width: 460)
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
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 160)
            HStack {
                Button("Cancel") {
                    viewModel.close()
                }
                Button("Translate") {
                    viewModel.confirmLongText()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .result(text):
            Text("Translation")
                .font(.headline)
            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            HStack {
                Spacer()
                Button("Close") {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .error(message):
            Text("Translation failed")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Close") {
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
}
