import Foundation

struct ClipboardInputSource: TextInputSource {
    let clipboard: any ClipboardTextReading

    init(clipboard: any ClipboardTextReading = ClipboardTextReader()) {
        self.clipboard = clipboard
    }

    func resolveText() async -> Result<String, TextInputSourceError> {
        guard let text = clipboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .failure(.noText)
        }
        return .success(text)
    }
}
