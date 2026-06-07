import Foundation

enum DocumentFormatter {
    static func format(text: String, fileName: String, syntaxMode: SyntaxHighlightMode) -> String? {
        switch resolvedMode(fileName: fileName, syntaxMode: syntaxMode) {
        case .json:
            return prettyJSON(text)
        case .html:
            return indentTagDocument(text)
        case .css:
            return indentBracedDocument(text)
        default:
            return nil
        }
    }

    static func minify(text: String, fileName: String, syntaxMode: SyntaxHighlightMode) -> String? {
        switch resolvedMode(fileName: fileName, syntaxMode: syntaxMode) {
        case .json:
            return minifyJSON(text)
        case .html, .css:
            return text
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        default:
            return nil
        }
    }

    private static func resolvedMode(fileName: String, syntaxMode: SyntaxHighlightMode) -> SyntaxHighlightMode {
        syntaxMode == .automatic ? SyntaxHighlightMode.detect(fileName: fileName, text: "") : syntaxMode
    }

    private static func prettyJSON(_ text: String) -> String? {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
            let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let output = String(data: formatted, encoding: .utf8)
        else {
            return nil
        }

        return output
    }

    private static func minifyJSON(_ text: String) -> String? {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
            let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let output = String(data: formatted, encoding: .utf8)
        else {
            return nil
        }

        return output
    }

    private static func indentTagDocument(_ text: String) -> String {
        let expanded = text
            .replacingOccurrences(of: "><", with: ">\n<")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var level = 0

        return expanded
            .components(separatedBy: "\n")
            .map { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { return "" }

                if line.hasPrefix("</") {
                    level = max(0, level - 1)
                }

                let output = String(repeating: "  ", count: level) + line

                if line.hasPrefix("<"),
                   !line.hasPrefix("</"),
                   !line.hasPrefix("<!"),
                   !line.hasSuffix("/>"),
                   !line.contains("</") {
                    level += 1
                }

                return output
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func indentBracedDocument(_ text: String) -> String {
        var lines: [String] = []
        var current = ""

        for character in text {
            if character == "{" || character == "}" || character == ";" {
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.append(character)
                    lines.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                } else {
                    lines.append(String(character))
                }
            } else {
                current.append(character)
            }
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var level = 0
        return lines.map { line in
            if line == "}" || line.hasPrefix("}") {
                level = max(0, level - 1)
            }

            let output = String(repeating: "  ", count: level) + line

            if line.hasSuffix("{") {
                level += 1
            }

            return output
        }.joined(separator: "\n")
    }
}

enum ScratchpadStore {
    static func url() throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("TextPort", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("Scratchpad.txt")
    }
}
