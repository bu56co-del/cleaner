import Foundation

public enum JSONValue: Codable, Sendable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    public subscript(_ key: String) -> JSONValue { if case .object(let v) = self { return v[key] ?? .null }; return .null }
    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var number: Double? { if case .number(let v) = self { return v }; return nil }
    public var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var array: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    public var object: [String: JSONValue] { if case .object(let v) = self { return v }; return [:] }
    public var display: String {
        switch self { case .string(let v): v.isEmpty ? "—" : v; case .number(let v): v.formatted(.number.precision(.fractionLength(0...2))); case .bool(let v): v ? "Yes" : "No"; case .null: "—"; default: "" }
    }
}

public struct InstalledApp: Decodable, Identifiable, Sendable, Hashable {
    public let name: String
    public let bundleID: String
    public let source: String
    public let uninstallName: String
    public let path: String
    public let size: String
    public var id: String { path }
    enum CodingKeys: String, CodingKey { case name, source, path, size; case bundleID = "bundle_id", uninstallName = "uninstall_name" }
}

public struct EngineDiskReport: Decodable, Sendable {
    public let path: String
    public let overview: Bool
    public let entries: [Entry]
    public let largeFiles: [LargeFile]?
    public let totalSize: Int64
    public let totalFiles: Int64?
    enum CodingKeys: String, CodingKey { case path, overview, entries; case largeFiles = "large_files", totalSize = "total_size", totalFiles = "total_files" }
    public struct Entry: Decodable, Sendable, Identifiable {
        public let name: String
        public let path: String
        public let size: Int64
        public let isDirectory: Bool
        public let insight: Bool?
        public let cleanable: Bool?
        public var id: String { path }
        enum CodingKeys: String, CodingKey { case name, path, size, insight, cleanable; case isDirectory = "is_dir" }
    }
    public struct LargeFile: Decodable, Sendable, Identifiable {
        public let name: String
        public let path: String
        public let size: Int64
        public var id: String { path }
    }
}
