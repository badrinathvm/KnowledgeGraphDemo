import Foundation

actor GraphAPIClient {
    static let shared = GraphAPIClient()
    private let base = URL(string: "http://localhost:8000")!
    private let decoder = JSONDecoder()

    private init() {}

    func fetchGraph() async throws -> GraphData {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("graph"))
        return try decoder.decode(GraphData.self, from: data)
    }

    func query(_ question: String) async throws -> QueryResponse {
        var request = URLRequest(url: base.appendingPathComponent("query"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["question": question])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(QueryResponse.self, from: data)
    }
}
