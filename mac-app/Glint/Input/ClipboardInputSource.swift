import Foundation

struct ClipboardInputSource: TextInputSource {
    let clipboard: any ClipboardTextReading

    init(clipboard: any ClipboardTextReading = ClipboardTextReader()) {
        self.clipboard = clipboard
    }

    func resolveText() async -> Result<String, TextInputFailure> {
        guard let text = clipboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .failure(TextInputFailure(.noText))
        }
        return .success(text)
    }
}
