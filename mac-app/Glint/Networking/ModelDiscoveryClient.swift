import Foundation

enum ModelDiscoveryClientError: Error, Equatable {
    case invalidResponse
    case invalidStatusCode(Int)
}

struct ModelDiscoveryClient {
    let config: AppConfig
    let session: URLSession

    init(config: AppConfig = .default, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func fetchModels() async throws -> [String] {
        var request = URLRequest(url: config.backendModelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = config.backendAPITimeout
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDiscoveryClientError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw ModelDiscoveryClientError.invalidStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return decoded.data.map(\.id).sorted()
    }
}
