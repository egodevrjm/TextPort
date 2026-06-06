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
        case .javascript:
            highlightCode(in: storage, string: string, keywords: javascriptKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .swift:
            highlightCode(in: storage, string: string, keywords: swiftKeywords, commentPattern: #"//.*|/\*[\s\S]*?\*/"#)
        case .python:
            highlightCode(in: storage, string: string, keywords: pythonKeywords, commentPattern: #"#.*"#)
        case .shell:
            highlightCode(in: storage, string: string, keywords: shellKeywords, commentPattern: #"#.*"#)
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

    private static let swiftKeywords = [
        "actor", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
        "default", "defer", "do", "else", "enum", "extension", "for", "func", "guard", "if",
        "import", "in", "init", "let", "nil", "private", "protocol", "public", "return", "self",
        "static", "struct", "switch", "throw", "try", "var", "while"
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
}
