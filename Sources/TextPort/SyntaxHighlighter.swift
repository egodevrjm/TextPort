import AppKit
import Foundation

@MainActor
enum SyntaxHighlighter {
    private static let maxHighlightedLength = 300_000

    static func apply(
        to textView: NSTextView,
        mode: SyntaxHighlightMode,
        customSyntaxDefinition: CustomSyntaxDefinition? = nil
    ) {
        guard let storage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        let font = textView.font ?? .monospacedSystemFont(ofSize: 14, weight: .regular)

        storage.beginEditing()
        storage.setAttributes([
            .font: font,
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        guard storage.length < maxHighlightedLength else {
            storage.endEditing()
            return
        }

        let string = storage.string as NSString

        if let customSyntaxDefinition {
            highlightCustom(in: storage, string: string, definition: customSyntaxDefinition)
            storage.endEditing()
            return
        }

        switch mode {
        case .automatic, .plainText:
            break
        case .json:
            highlightJSON(in: storage, string: string)
        case .markdown:
            highlightMarkdown(in: storage, string: string, baseFont: font)
        case .html:
            highlightHTML(in: storage, string: string)
        case .css:
            highlightCSS(in: storage, string: string)
        case .cFamily:
            highlightCode(
                in: storage,
                string: string,
                keywords: cFamilyKeywords,
                commentPattern: #"//.*|/\*[\s\S]*?\*/"#,
                annotationPattern: #"#[A-Za-z_][A-Za-z0-9_]*"#
            )
        case .go:
            highlightCode(in: storage, string: string, keywords: goKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .javascript:
            highlightCode(
                in: storage,
                string: string,
                keywords: javascriptKeywords,
                commentPattern: #"//.*|/\*[\s\S]*?\*/"#,
                annotationPattern: #"@[A-Za-z_][A-Za-z0-9_]*"#
            )
        case .java:
            highlightCode(
                in: storage,
                string: string,
                keywords: javaKeywords,
                commentPattern: #"//.*|/\*[\s\S]*?\*/"#,
                annotationPattern: #"@[A-Za-z_][A-Za-z0-9_]*"#
            )
        case .swift:
            highlightCode(
                in: storage,
                string: string,
                keywords: swiftKeywords,
                commentPattern: #"//.*|/\*[\s\S]*?\*/"#,
                annotationPattern: #"@[A-Za-z_][A-Za-z0-9_]*"#
            )
        case .python:
            highlightCode(
                in: storage,
                string: string,
                keywords: pythonKeywords,
                commentPattern: #"#.*"#,
                annotationPattern: #"(?m)^\s*@[A-Za-z_][A-Za-z0-9_\.]*"#
            )
        case .ruby:
            highlightCode(in: storage, string: string, keywords: rubyKeywords, commentPattern: #"#.*"#)
        case .rust:
            highlightCode(
                in: storage,
                string: string,
                keywords: rustKeywords,
                commentPattern: #"//.*|/\*[\s\S]*?\*/"#,
                annotationPattern: #"#\!?|\#\[.*?\]"#
            )
        case .shell:
            highlightShell(in: storage, string: string)
        case .sql:
            highlightCode(in: storage, string: string, keywords: sqlKeywords, commentPattern: #"--.*|/\*[\s\S]*?\*/"#)
        case .toml:
            highlightKeyValueData(in: storage, string: string, commentPattern: #"(?m)#.*$"#)
        case .yaml:
            highlightKeyValueData(in: storage, string: string, commentPattern: #"(?m)#.*$"#)
        }

        storage.endEditing()
    }

    private static func highlightJSON(in storage: NSTextStorage, string: NSString) {
        apply(pattern: #""(?:\\.|[^"\\])*"\s*:"#, attributes: [.foregroundColor: NSColor.systemBlue], storage: storage, string: string)
        apply(pattern: #""(?:\\.|[^"\\])*""#, color: .systemRed, storage: storage, string: string)
        apply(pattern: #"\b(true|false)\b"#, color: .systemPurple, storage: storage, string: string)
        apply(pattern: #"\bnull\b"#, color: .tertiaryLabelColor, storage: storage, string: string)
        apply(pattern: #"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, color: .systemOrange, storage: storage, string: string)
        apply(pattern: #"[{}\[\],:]"#, color: .secondaryLabelColor, storage: storage, string: string)
    }

    private static func highlightMarkdown(in storage: NSTextStorage, string: NSString, baseFont: NSFont) {
        apply(
            pattern: #"(?m)^#{1,6}\s.*$"#,
            attributes: [
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .semibold)
            ],
            storage: storage,
            string: string
        )
        apply(pattern: #"(?m)^>\s?.*$"#, color: .systemIndigo, storage: storage, string: string)
        apply(pattern: #"(?m)^\s*[-*+]\s+"#, color: .systemOrange, storage: storage, string: string)
        apply(pattern: #"\[[^\]]+\]\([^)]+\)"#, color: .systemTeal, storage: storage, string: string)
        apply(pattern: #"\*\*[^*]+\*\*|__[^_]+__"#, color: .systemRed, storage: storage, string: string)
        apply(pattern: #"(?<!\*)\*[^*\n]+\*(?!\*)|_[^_\n]+_"#, color: .systemPink, storage: storage, string: string)
        apply(pattern: #"`[^`]+`"#, color: .systemPurple, storage: storage, string: string)
        apply(pattern: #"(?m)^```[\s\S]*?^```"#, color: .systemPurple, storage: storage, string: string)
    }

    private static func highlightHTML(in storage: NSTextStorage, string: NSString) {
        applyDelimitedStrings(in: storage, string: string, delimiters: ["\"", "'"])
        apply(pattern: #"</?[A-Za-z][^>\s/]*"#, color: .systemBlue, storage: storage, string: string)
        apply(pattern: #"\b[A-Za-z_:][-A-Za-z0-9_:.]*(?=\s*=)"#, color: .systemPurple, storage: storage, string: string)
        apply(pattern: #"&[A-Za-z0-9#]+;"#, color: .systemOrange, storage: storage, string: string)
        apply(pattern: #"<!--[\s\S]*?-->"#, color: .systemGreen, storage: storage, string: string)
    }

    private static func highlightCSS(in storage: NSTextStorage, string: NSString) {
        applyDelimitedStrings(in: storage, string: string, delimiters: ["\"", "'"])
        apply(pattern: #"(?m)[.#]?[A-Za-z_][\w-]*(?=\s*\{)"#, color: .systemBlue, storage: storage, string: string)
        apply(pattern: #"\b[A-Za-z-]+(?=\s*:)"#, color: .systemPurple, storage: storage, string: string)
        apply(pattern: #"#[0-9A-Fa-f]{3,8}\b|\b\d+(?:\.\d+)?(?:px|rem|em|%|vh|vw|s|ms)?\b"#, color: .systemOrange, storage: storage, string: string)
        apply(pattern: #"/\*[\s\S]*?\*/"#, color: .systemGreen, storage: storage, string: string)
    }

    private static func highlightCode(
        in storage: NSTextStorage,
        string: NSString,
        keywords: [String],
        commentPattern: String,
        annotationPattern: String? = nil
    ) {
        applyDelimitedStrings(in: storage, string: string, delimiters: ["\"", "'", "`"])
        apply(pattern: #"\b\d+(?:\.\d+)?\b"#, color: .systemOrange, storage: storage, string: string)
        applyKeywords(keywords, color: .systemBlue, storage: storage, string: string)

        if let annotationPattern {
            apply(pattern: annotationPattern, color: .systemPink, storage: storage, string: string)
        }

        apply(pattern: commentPattern, color: .systemGreen, storage: storage, string: string)
    }

    private static func highlightShell(in storage: NSTextStorage, string: NSString) {
        applyDelimitedStrings(in: storage, string: string, delimiters: ["\"", "'", "`"])
        apply(pattern: #"\$[A-Za-z_][A-Za-z0-9_]*|\$\{[^}]+\}"#, color: .systemPurple, storage: storage, string: string)
        applyKeywords(shellKeywords, color: .systemBlue, storage: storage, string: string)
        apply(pattern: #"#.*"#, color: .systemGreen, storage: storage, string: string)
    }

    private static func highlightKeyValueData(
        in storage: NSTextStorage,
        string: NSString,
        commentPattern: String
    ) {
        applyDelimitedStrings(in: storage, string: string, delimiters: ["\"", "'"])
        apply(pattern: #"(?m)^\s*[A-Za-z0-9_.-]+(?=\s*[:=])"#, color: .systemBlue, storage: storage, string: string)
        apply(pattern: #"\b(true|false|null|yes|no|on|off)\b|\b\d+(?:\.\d+)?\b"#, color: .systemOrange, storage: storage, string: string)
        apply(pattern: commentPattern, color: .systemGreen, storage: storage, string: string)
    }

    private static func highlightCustom(
        in storage: NSTextStorage,
        string: NSString,
        definition: CustomSyntaxDefinition
    ) {
        applyDelimitedStrings(in: storage, string: string, delimiters: definition.stringDelimiters)
        apply(pattern: #"\b\d+(?:\.\d+)?\b"#, color: .systemOrange, storage: storage, string: string)
        applyKeywords(
            definition.keywords,
            color: .systemBlue,
            storage: storage,
            string: string,
            caseSensitive: definition.caseSensitive
        )

        if !definition.blockCommentStart.isEmpty, !definition.blockCommentEnd.isEmpty {
            let start = NSRegularExpression.escapedPattern(for: definition.blockCommentStart)
            let end = NSRegularExpression.escapedPattern(for: definition.blockCommentEnd)
            apply(pattern: "\(start)[\\s\\S]*?\(end)", color: .systemGreen, storage: storage, string: string)
        }

        if !definition.singleLineComment.isEmpty {
            let marker = NSRegularExpression.escapedPattern(for: definition.singleLineComment)
            apply(pattern: "(?m)\(marker).*?$", color: .systemGreen, storage: storage, string: string)
        }
    }

    private static func applyDelimitedStrings(
        in storage: NSTextStorage,
        string: NSString,
        delimiters: [String]
    ) {
        for delimiter in delimiters.normalizedSyntaxList {
            let pattern: String
            switch delimiter {
            case "\"":
                pattern = #""(?:\\.|[^"\\])*""#
            case "'":
                pattern = #"'(?:\\.|[^'\\])*'"#
            case "`":
                pattern = #"`(?:\\.|[^`\\])*`"#
            default:
                let escaped = NSRegularExpression.escapedPattern(for: delimiter)
                pattern = "\(escaped)[\\s\\S]*?\(escaped)"
            }

            apply(pattern: pattern, color: .systemRed, storage: storage, string: string)
        }
    }

    private static func applyKeywords(
        _ keywords: [String],
        color: NSColor,
        storage: NSTextStorage,
        string: NSString,
        caseSensitive: Bool = true
    ) {
        let normalizedKeywords = keywords.normalizedSyntaxList
        guard !normalizedKeywords.isEmpty else { return }

        let keywordPattern = normalizedKeywords
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]

        apply(
            pattern: "(?<![A-Za-z0-9_])(\(keywordPattern))(?![A-Za-z0-9_])",
            options: options,
            color: color,
            storage: storage,
            string: string
        )
    }

    private static func apply(
        pattern: String,
        color: NSColor,
        storage: NSTextStorage,
        string: NSString
    ) {
        apply(pattern: pattern, attributes: [.foregroundColor: color], storage: storage, string: string)
    }

    private static func apply(
        pattern: String,
        options: NSRegularExpression.Options = [],
        color: NSColor,
        storage: NSTextStorage,
        string: NSString
    ) {
        apply(pattern: pattern, options: options, attributes: [.foregroundColor: color], storage: storage, string: string)
    }

    private static func apply(
        pattern: String,
        options: NSRegularExpression.Options = [],
        attributes: [NSAttributedString.Key: Any],
        storage: NSTextStorage,
        string: NSString
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let fullRange = NSRange(location: 0, length: string.length)
        regex.enumerateMatches(in: string as String, range: fullRange) { match, _, _ in
            guard let match else { return }
            storage.addAttributes(attributes, range: match.range)
        }
    }

    private static let javascriptKeywords = [
        "abstract", "as", "asserts", "async", "await", "break", "case", "catch", "class", "const",
        "continue", "debugger", "default", "delete", "else", "enum", "export", "extends", "false",
        "finally", "for", "from", "function", "get", "if", "implements", "import", "in", "instanceof",
        "interface", "let", "new", "null", "of", "private", "protected", "public", "return", "set",
        "static", "super", "switch", "this", "throw", "true", "try", "type", "typeof", "undefined",
        "var", "void", "while", "yield"
    ]

    private static let cFamilyKeywords = [
        "auto", "bool", "break", "case", "char", "class", "const", "constexpr", "continue", "default",
        "delete", "do", "double", "else", "enum", "extern", "false", "float", "for", "if", "include",
        "inline", "int", "long", "namespace", "new", "nullptr", "operator", "private", "protected",
        "public", "return", "short", "sizeof", "static", "struct", "switch", "template", "this",
        "true", "typedef", "typename", "union", "unsigned", "using", "virtual", "void", "volatile", "while"
    ]

    private static let goKeywords = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for",
        "func", "go", "goto", "if", "import", "interface", "map", "nil", "package", "range", "return",
        "select", "struct", "switch", "type", "var"
    ]

    private static let swiftKeywords = [
        "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class",
        "continue", "default", "defer", "do", "else", "enum", "extension", "false", "fileprivate",
        "for", "func", "guard", "if", "import", "in", "init", "inout", "is", "let", "nil", "nonisolated",
        "open", "operator", "private", "protocol", "public", "return", "self", "some", "static", "struct",
        "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while"
    ]

    private static let javaKeywords = [
        "abstract", "assert", "boolean", "break", "case", "catch", "class", "const", "continue", "default",
        "do", "double", "else", "enum", "extends", "false", "final", "finally", "float", "for", "if",
        "implements", "import", "instanceof", "int", "interface", "long", "new", "null", "package",
        "private", "protected", "public", "return", "short", "static", "super", "switch", "this", "throw",
        "throws", "true", "try", "void", "while"
    ]

    private static let pythonKeywords = [
        "and", "as", "assert", "async", "await", "break", "case", "class", "continue", "def",
        "del", "elif", "else", "except", "False", "finally", "for", "from", "global", "if",
        "import", "in", "is", "lambda", "match", "None", "nonlocal", "not", "or", "pass",
        "raise", "return", "True", "try", "while", "with", "yield"
    ]

    private static let shellKeywords = [
        "case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if",
        "in", "select", "then", "until", "while"
    ]

    private static let rubyKeywords = [
        "alias", "and", "begin", "break", "case", "class", "def", "defined", "do", "else", "elsif",
        "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
        "rescue", "retry", "return", "self", "super", "then", "true", "unless", "until", "when", "while", "yield"
    ]

    private static let rustKeywords = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
        "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
        "ref", "return", "self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use",
        "where", "while"
    ]

    private static let sqlKeywords = [
        "alter", "and", "as", "between", "by", "case", "create", "delete", "distinct", "drop", "else",
        "end", "exists", "from", "group", "having", "in", "insert", "into", "is", "join", "left",
        "like", "limit", "not", "null", "on", "or", "order", "outer", "right", "select", "set",
        "table", "then", "union", "update", "values", "when", "where"
    ]
}
