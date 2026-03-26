struct TextLengthPolicy: Equatable {
    enum Evaluation: Equatable {
        case allowed
        case needsConfirmation
        case rejected
    }

    let softLimit: Int
    let hardLimit: Int

    func evaluate(_ text: String) -> Evaluation {
        let length = text.count
        if length > hardLimit {
            return .rejected
        }
        if length > softLimit {
            return .needsConfirmation
        }
        return .allowed
    }
}
