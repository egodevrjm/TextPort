import AppKit
import Foundation

@MainActor
enum SyntaxHighlighter {
    static func apply(to textView: NSTextView, mode: SyntaxHighlightMode) {
        guard let storage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        let font = textView.font ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        let baseColor = NSColor.labelColor

        storage.beginEditing()
        storage.setAttributes([
            .font: font,
            .foregroundColor: baseColor
        ], range: fullRange)

        guard mode != .plainText, storage.length < 300_000 else {
            storage.endEditing()
            return
        }

        let string = storage.string as NSString

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
            highlightCode(in: storage, string: string, keywords: cFamilyKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .go:
            highlightCode(in: storage, string: string, keywords: goKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .javascript:
            highlightCode(in: storage, string: string, keywords: javascriptKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .java:
            highlightCode(in: storage, string: string, keywords: javaKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .swift:
            highlightCode(in: storage, string: string, keywords: swiftKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .python:
            highlightCode(in: storage, string: string, keywords: pythonKeywords, commentPattern: #"#.*"#)
        case .ruby:
            highlightCode(in: storage, string: string, keywords: rubyKeywords, commentPattern: #"#.*"#)
        case .rust:
            highlightCode(in: storage, string: string, keywords: rustKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .shell:
            highlightCode(in: storage, string: string, keywords: shellKeywords, commentPattern: #"#.*"#)
        case .sql:
            highlightCode(in: storage, string: string, keywords: sqlKeywords, commentPattern: #"--.*|/\*[\s\S]*?\*/"#)
        case .toml:
            highlightKeyValueData(in: storage, string: string)
        case .yaml:
            highlightKeyValueData(in: storage, string: string)
        }

        storage.endEditing()
    }

    private static func highlightJSON(in storage: NSTextStorage, string: NSString) {
        apply(pattern: #""(?:\\.|[^"\\])*"\s*:"#,
              color: .systemBlue,
              storage: storage,
              string: string)
        apply(pattern: #""(?:\\.|[^"\\])*""#,
              color: .systemRed,
              storage: storage,
              string: string)
        apply(pattern: #"\b(true|false|null)\b"#,
              color: .systemPurple,
              storage: storage,
              string: string)
        apply(pattern: #"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#,
              color: .systemOrange,
              storage: storage,
              string: string)
    }

    private static func highlightMarkdown(in storage: NSTextStorage, string: NSString, baseFont: NSFont) {
        apply(pattern: #"(?m)^#{1,6}\s.*$"#,
              attributes: [.foregroundColor: NSColor.systemBlue, .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .semibold)],
              storage: storage,
              string: string)
        apply(pattern: #"`[^`]+`"#,
              color: .systemPurple,
              storage: storage,
              string: string)
        apply(pattern: #"\*\*[^*]+\*\*|__[^_]+__"#,
              color: .systemRed,
              storage: storage,
              string: string)
        apply(pattern: #"(?m)^\s*[-*+]\s+"#,
              color: .systemOrange,
              storage: storage,
              string: string)
        apply(pattern: #"\[[^\]]+\]\([^)]+\)"#,
              color: .systemTeal,
              storage: storage,
              string: string)
    }

    private static func highlightHTML(in storage: NSTextStorage, string: NSString) {
        apply(pattern: #"<!--[\s\S]*?-->"#,
              color: .systemGreen,
              storage: storage,
              string: string)
        apply(pattern: #"</?[A-Za-z][^>\s/]*"#,
              color: .systemBlue,
              storage: storage,
              string: string)
        apply(pattern: #"\b[A-Za-z-]+="#,
              color: .systemPurple,
              storage: storage,
              string: string)
        apply(pattern: #""[^"]*"|'[^']*'"#,
              color: .systemRed,
              storage: storage,
              string: string)
    }

    private static func highlightCSS(in storage: NSTextStorage, string: NSString) {
        apply(pattern: #"/\*[\s\S]*?\*/"#,
              color: .systemGreen,
              storage: storage,
              string: string)
        apply(pattern: #"(?m)[.#]?[A-Za-z_][\w-]*(?=\s*\{)"#,
              color: .systemBlue,
              storage: storage,
              string: string)
        apply(pattern: #"\b[A-Za-z-]+(?=\s*:)"#,
              color: .systemPurple,
              storage: storage,
              string: string)
        apply(pattern: #"#[0-9A-Fa-f]{3,8}\b|\b\d+(?:\.\d+)?(?:px|rem|em|%|vh|vw)?\b"#,
              color: .systemOrange,
              storage: storage,
              string: string)
    }

    private static func highlightCode(
        in storage: NSTextStorage,
        string: NSString,
        keywords: [String],
        commentPattern: String
    ) {
        apply(pattern: commentPattern,
              color: .systemGreen,
              storage: storage,
              string: string)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#,
              color: .systemRed,
              storage: storage,
              string: string)
        apply(pattern: #"\b\d+(?:\.\d+)?\b"#,
              color: .systemOrange,
              storage: storage,
              string: string)
        apply(pattern: #"\b("# + keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + #")\b"#,
              color: .systemBlue,
              storage: storage,
              string: string)
    }

    private static func highlightKeyValueData(in storage: NSTextStorage, string: NSString) {
        apply(pattern: #"(?m)^\s*[A-Za-z0-9_.-]+(?=\s*[:=])"#,
              color: .systemBlue,
              storage: storage,
              string: string)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#,
              color: .systemRed,
              storage: storage,
              string: string)
        apply(pattern: #"\b(true|false|null)\b|\b\d+(?:\.\d+)?\b"#,
              color: .systemOrange,
              storage: storage,
              string: string)
        apply(pattern: #"(?m)#.*$"#,
              color: .systemGreen,
              storage: storage,
              string: string)
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
        attributes: [NSAttributedString.Key: Any],
        storage: NSTextStorage,
        string: NSString
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let fullRange = NSRange(location: 0, length: string.length)
        regex.enumerateMatches(in: string as String, range: fullRange) { match, _, _ in
            guard let match else { return }
            storage.addAttributes(attributes, range: match.range)
        }
    }

    private static let javascriptKeywords = [
        "await", "async", "break", "case", "catch", "class", "const", "continue", "default", "else",
        "export", "extends", "finally", "for", "from", "function", "if", "import", "let", "new",
        "return", "switch", "throw", "try", "var", "while", "yield"
    ]

    private static let cFamilyKeywords = [
        "auto", "break", "case", "char", "class", "const", "continue", "default", "delete", "do",
        "double", "else", "enum", "extern", "float", "for", "if", "include", "int", "long",
        "namespace", "new", "private", "protected", "public", "return", "short", "sizeof", "static", "struct",
        "switch", "template", "typedef", "union", "unsigned", "using", "virtual", "void", "while"
    ]

    private static let goKeywords = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for",
        "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return",
        "select", "struct", "switch", "type", "var"
    ]

    private static let swiftKeywords = [
        "actor", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
        "default", "defer", "do", "else", "enum", "extension", "for", "func", "guard", "if",
        "import", "in", "init", "let", "nil", "private", "protocol", "public", "return", "self",
        "static", "struct", "switch", "throw", "try", "var", "while"
    ]

    private static let javaKeywords = [
        "abstract", "boolean", "break", "case", "catch", "class", "const", "continue", "default", "do",
        "double", "else", "enum", "extends", "final", "finally", "for", "if", "implements", "import",
        "int", "interface", "long", "new", "null", "package", "private", "protected", "public", "return",
        "static", "super", "switch", "this", "throw", "throws", "try", "void", "while"
    ]

    private static let pythonKeywords = [
        "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del",
        "elif", "else", "except", "False", "finally", "for", "from", "if", "import", "in",
        "is", "lambda", "None", "not", "or", "pass", "raise", "return", "True", "try",
        "while", "with", "yield"
    ]

    private static let shellKeywords = [
        "case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if",
        "in", "select", "then", "until", "while"
    ]

    private static let rubyKeywords = [
        "alias", "and", "begin", "break", "case", "class", "def", "do", "else", "elsif",
        "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not",
        "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "unless",
        "until", "when", "while", "yield"
    ]

    private static let rustKeywords = [
        "as", "async", "await", "break", "const", "continue", "crate", "else", "enum", "extern",
        "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod",
        "move", "mut", "pub", "ref", "return", "self", "static", "struct", "super", "trait",
        "true", "type", "unsafe", "use", "where", "while"
    ]

    private static let sqlKeywords = [
        "alter", "and", "as", "between", "by", "case", "create", "delete", "drop", "else",
        "end", "from", "group", "having", "in", "insert", "into", "is", "join", "left",
        "like", "limit", "not", "null", "on", "or", "order", "right", "select", "set",
        "table", "then", "union", "update", "values", "when", "where"
    ]
}
