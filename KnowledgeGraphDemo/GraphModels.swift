import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)   { self = .bool(v);   return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if c.decodeNil()                       { self = .null;      return }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }
}

struct GraphNode: Identifiable, Codable {
    let id: String
    let label: String
    let name: String
    let properties: [String: JSONValue]?
}

struct GraphEdge: Identifiable, Codable {
    let id: String
    let source: String
    let target: String
    let type: String
}

struct GraphData: Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
}

struct QueryResponse: Codable {
    let answer: String
    let highlightedNodeIds: [String]

    enum CodingKeys: String, CodingKey {
        case answer
        case highlightedNodeIds = "highlighted_node_ids"
    }
}
