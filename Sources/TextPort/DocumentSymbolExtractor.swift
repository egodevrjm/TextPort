import Foundation

struct DocumentSymbol: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let lineNumber: Int
    let level: Int
}

enum DocumentSymbolExtractor {
    static func symbols(in tab: TextDocumentTab, mode: SyntaxHighlightMode) -> [DocumentSymbol] {
        let lines = tab.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        switch mode {
        case .markdown:
            return markdownSymbols(lines)
        case .json:
            return jsonSymbols(tab.text)
        case .html:
            return htmlSymbols(lines)
        default:
            return codeSymbols(lines)
        }
    }

    private static func markdownSymbols(_ lines: [String]) -> [DocumentSymbol] {
        lines.enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let level = trimmed.prefix { $0 == "#" }.count
            guard (1...6).contains(level), trimmed.dropFirst(level).first == " " else { return nil }
            return DocumentSymbol(
                title: String(trimmed.dropFirst(level + 1)),
                detail: "Heading \(level)",
                lineNumber: index + 1,
                level: level
            )
        }
    }

    private static func jsonSymbols(_ text: String) -> [DocumentSymbol] {
        guard case .success(let root) = JSONPreviewParser.parse(text) else { return [] }
        return jsonSymbols(value: root, name: "root", lineNumber: 1, level: 1)
    }

    private static func jsonSymbols(value: JSONPreviewValue, name: String, lineNumber: Int, level: Int) -> [DocumentSymbol] {
        var symbols = [DocumentSymbol(title: name, detail: valueOutlineLabel(value), lineNumber: lineNumber, level: level)]

        switch value {
        case .object(let entries):
            for entry in entries where !entry.value.isScalarForSymbols {
                symbols.append(contentsOf: jsonSymbols(value: entry.value, name: entry.key, lineNumber: lineNumber, level: level + 1))
            }
        case .array(let values):
            if let first = values.first, !first.isScalarForSymbols {
                symbols.append(contentsOf: jsonSymbols(value: first, name: "items", lineNumber: lineNumber, level: level + 1))
            }
        case .string, .number, .bool, .null:
            break
        }

        return symbols
    }

    private static func valueOutlineLabel(_ value: JSONPreviewValue) -> String {
        switch value {
        case .object(let entries):
            return "\(entries.count) fields"
        case .array(let values):
            return "\(values.count) items"
        case .string:
            return "String"
        case .number:
            return "Number"
        case .bool:
            return "Boolean"
        case .null:
            return "Null"
        }
    }

    private static func htmlSymbols(_ lines: [String]) -> [DocumentSymbol] {
        lines.enumerated().compactMap { index, line in
            guard let range = line.range(of: #"<(h[1-6]|section|article|main|nav|header|footer)\b[^>]*>"#, options: .regularExpression) else {
                return nil
            }
            let tag = line[range]
                .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                .components(separatedBy: .whitespaces)
                .first ?? "tag"
            let level = tag.hasPrefix("h") ? Int(String(tag.dropFirst())) ?? 2 : 2
            return DocumentSymbol(title: tag, detail: "HTML", lineNumber: index + 1, level: level)
        }
    }

    private static func codeSymbols(_ lines: [String]) -> [DocumentSymbol] {
        lines.enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let patterns = [
                #"^(func|function|def|class|struct|enum|interface|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
                #"^(let|var|const)\s+([A-Za-z_][A-Za-z0-9_]*)\s*="#
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)),
                   match.numberOfRanges >= 3 {
                    let kind = (trimmed as NSString).substring(with: match.range(at: 1))
                    let name = (trimmed as NSString).substring(with: match.range(at: 2))
                    return DocumentSymbol(title: name, detail: kind, lineNumber: index + 1, level: 1)
                }
            }

            return nil
        }
    }
}

private extension JSONPreviewValue {
    var isScalarForSymbols: Bool {
        switch self {
        case .object, .array:
            return false
        case .string, .number, .bool, .null:
            return true
        }
    }
}
