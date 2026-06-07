import Foundation
import SwiftUI

struct JSONPreviewView: View {
    let json: String

    private var parseResult: Result<JSONPreviewValue, Error> {
        JSONPreviewParser.parse(json)
    }

    var body: some View {
        switch parseResult {
        case .success(let root):
            ScrollView([.horizontal, .vertical]) {
                JSONNodeView(label: nil, value: root, depth: 0)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        case .failure(let error):
            PreviewUnavailableView(
                title: "Invalid JSON",
                message: "TextPort could not parse this file as JSON. \(error.localizedDescription)"
            )
        }
    }
}

private struct JSONNodeView: View {
    let label: String?
    let value: JSONPreviewValue
    let depth: Int

    @State private var isExpanded: Bool

    init(label: String?, value: JSONPreviewValue, depth: Int) {
        self.label = label
        self.value = value
        self.depth = depth
        _isExpanded = State(initialValue: depth < 2)
    }

    var body: some View {
        Group {
            switch value {
            case .object(let entries):
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entries) { entry in
                            JSONNodeView(label: entry.key, value: entry.value, depth: depth + 1)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                } label: {
                    containerLabel(summary: "\(entries.count) keys")
                }
            case .array(let values):
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                            JSONNodeView(label: "[\(index)]", value: value, depth: depth + 1)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                } label: {
                    containerLabel(summary: "\(values.count) items")
                }
            case .string(let string):
                leafLabel(value: "\"\(string)\"", color: .primary)
            case .number(let number):
                leafLabel(value: number, color: .orange)
            case .bool(let bool):
                leafLabel(value: bool ? "true" : "false", color: .purple)
            case .null:
                leafLabel(value: "null", color: .secondary)
            }
        }
        .font(.system(size: 13, design: .monospaced))
    }

    private func containerLabel(summary: String) -> some View {
        HStack(spacing: 8) {
            keyLabel

            Text(summary)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    private func leafLabel(value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            keyLabel

            Text(value)
                .foregroundStyle(color)
                .textSelection(.enabled)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var keyLabel: some View {
        if let label {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(":")
                .foregroundStyle(.secondary)
        } else {
            Text("root")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
}

enum JSONPreviewParser {
    static func parse(_ json: String) -> Result<JSONPreviewValue, Error> {
        do {
            let data = Data(json.utf8)
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return .success(JSONPreviewValue.make(from: object))
        } catch {
            return .failure(error)
        }
    }
}

struct JSONPreviewObjectEntry: Identifiable {
    let id = UUID()
    let key: String
    let value: JSONPreviewValue
}

indirect enum JSONPreviewValue {
    case object([JSONPreviewObjectEntry])
    case array([JSONPreviewValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    static func make(from object: Any) -> JSONPreviewValue {
        if object is NSNull {
            return .null
        }

        if let number = object as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }

            return .number(number.stringValue)
        }

        if let string = object as? String {
            return .string(string)
        }

        if let dictionary = object as? [String: Any] {
            return .object(dictionary.keys.sorted().map { key in
                JSONPreviewObjectEntry(key: key, value: dictionary[key].map(make(from:)) ?? .null)
            })
        }

        if let array = object as? [Any] {
            return .array(array.map(make(from:)))
        }

        return .string(String(describing: object))
    }
}
