import Foundation

struct CustomSyntaxDefinition: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var fileExtensions: [String]
    var keywords: [String]
    var singleLineComment: String
    var blockCommentStart: String
    var blockCommentEnd: String
    var stringDelimiters: [String]
    var caseSensitive: Bool

    init(
        id: UUID = UUID(),
        name: String = "Custom Syntax",
        fileExtensions: [String] = [],
        keywords: [String] = [],
        singleLineComment: String = "",
        blockCommentStart: String = "",
        blockCommentEnd: String = "",
        stringDelimiters: [String] = ["\"", "'"],
        caseSensitive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.fileExtensions = fileExtensions.normalizedSyntaxList
        self.keywords = keywords.normalizedSyntaxList
        self.singleLineComment = singleLineComment
        self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd
        self.stringDelimiters = stringDelimiters.normalizedSyntaxList
        self.caseSensitive = caseSensitive
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Custom Syntax" : trimmed
    }

    var isValid: Bool {
        !displayName.isEmpty
    }

    func matches(fileName: String, text: String) -> Bool {
        let fileExtension = fileName.fileExtension.lowercased()
        if !fileExtension.isEmpty, fileExtensions.contains(fileExtension) {
            return true
        }

        guard let firstLine = text.components(separatedBy: .newlines).first?.lowercased(),
              firstLine.hasPrefix("#!")
        else {
            return false
        }

        return fileExtensions.contains { firstLine.contains($0) }
    }

    static func starter(named name: String = "Custom Syntax") -> CustomSyntaxDefinition {
        CustomSyntaxDefinition(
            name: name,
            fileExtensions: ["txt"],
            keywords: ["todo", "note", "important"],
            singleLineComment: "#",
            blockCommentStart: "",
            blockCommentEnd: "",
            stringDelimiters: ["\"", "'"],
            caseSensitive: false
        )
    }
}

extension Array where Element == String {
    var normalizedSyntaxList: [String] {
        var seen = Set<String>()
        return compactMap { item in
            let trimmed = item
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }
}

enum SyntaxListParser {
    static func parse(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n\t")
        return text.components(separatedBy: separators).normalizedSyntaxList
    }

    static func display(_ values: [String]) -> String {
        values.joined(separator: ", ")
    }
}
