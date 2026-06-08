import Foundation

enum MarkdownHTMLRenderer {
    static func html(for markdown: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root {
            color-scheme: light dark;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            background: transparent;
            color: CanvasText;
        }
        body {
            margin: 0;
            padding: 34px;
            background: transparent;
            font-size: 15px;
            line-height: 1.55;
        }
        main {
            max-width: 820px;
            margin: 0 auto;
        }
        h1, h2, h3, h4, h5, h6 {
            line-height: 1.2;
            margin: 1.1em 0 0.45em;
        }
        h1 {
            font-size: 2em;
            padding-bottom: 0.25em;
            border-bottom: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
        }
        h2 { font-size: 1.55em; }
        h3 { font-size: 1.25em; }
        p { margin: 0.65em 0; }
        a { color: LinkText; }
        blockquote {
            margin: 1em 0;
            padding: 0.2em 1em;
            border-left: 3px solid color-mix(in srgb, CanvasText 28%, transparent);
            color: color-mix(in srgb, CanvasText 72%, transparent);
        }
        code {
            font-family: "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.92em;
            padding: 0.12em 0.32em;
            border-radius: 4px;
            background: color-mix(in srgb, CanvasText 9%, transparent);
        }
        pre {
            overflow: auto;
            padding: 13px 15px;
            margin: 0;
            border-radius: 0 0 8px 8px;
            background: color-mix(in srgb, CanvasText 9%, transparent);
        }
        figure.code-block {
            margin: 1em 0;
            border: 1px solid color-mix(in srgb, CanvasText 12%, transparent);
            border-radius: 8px;
            overflow: hidden;
            background: color-mix(in srgb, CanvasText 5%, transparent);
        }
        figcaption {
            padding: 6px 12px;
            font-family: "SF Mono", Menlo, Consolas, monospace;
            font-size: 12px;
            color: color-mix(in srgb, CanvasText 68%, transparent);
            border-bottom: 1px solid color-mix(in srgb, CanvasText 10%, transparent);
        }
        pre code {
            padding: 0;
            background: transparent;
            border-radius: 0;
        }
        ul, ol { padding-left: 1.45em; }
        li { margin: 0.28em 0; }
        li.task {
            list-style: none;
            margin-left: -1.35em;
        }
        li.task input {
            margin-right: 0.45em;
            vertical-align: -0.12em;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
        }
        th, td {
            border: 1px solid color-mix(in srgb, CanvasText 16%, transparent);
            padding: 7px 9px;
            text-align: left;
            vertical-align: top;
        }
        th {
            background: color-mix(in srgb, CanvasText 8%, transparent);
            font-weight: 600;
        }
        hr {
            border: 0;
            border-top: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
            margin: 1.5em 0;
        }
        img {
            max-width: 100%;
            height: auto;
        }
        .empty {
            height: calc(100vh - 68px);
            display: grid;
            place-items: center;
            color: color-mix(in srgb, CanvasText 45%, transparent);
            font-size: 14px;
        }
        </style>
        </head>
        <body>
        <main>
        \(MarkdownBlockParser(markdown: markdown).render())
        </main>
        </body>
        </html>
        """
    }
}

private struct MarkdownBlockParser {
    let markdown: String

    func render() -> String {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "<div class=\"empty\">Nothing to preview yet.</div>"
        }

        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [String] = []
        var paragraph: [String] = []
        var listItems: [MarkdownListItem] = []
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append("<p>\(MarkdownInlineRenderer.render(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            let tag = listItems.allSatisfy(\.ordered) ? "ol" : "ul"
            let items = listItems
                .map { item -> String in
                    let renderedText = MarkdownInlineRenderer.render(item.text)
                    if let checked = item.checked {
                        let checkedAttribute = checked ? " checked" : ""
                        return "<li class=\"task\"><input type=\"checkbox\" disabled\(checkedAttribute)><span>\(renderedText)</span></li>"
                    }

                    return "<li>\(renderedText)</li>"
                }
                .joined(separator: "\n")
            blocks.append("<\(tag)>\n\(items)\n</\(tag)>")
            listItems.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                flushList()
                let marker = String(trimmed.prefix(3))
                let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                index += 1
                var codeLines: [String] = []

                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix(marker) {
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }

                if index < lines.count {
                    index += 1
                }

                let languageClass = language.isEmpty ? "" : " class=\"language-\(HTML.escapeAttribute(language))\""
                let caption = language.isEmpty ? "" : "<figcaption>\(HTML.escape(language))</figcaption>"
                blocks.append("<figure class=\"code-block\">\(caption)<pre><code\(languageClass)>\(HTML.escape(codeLines.joined(separator: "\n")))</code></pre></figure>")
                continue
            }

            if let heading = MarkdownPatterns.heading(in: trimmed) {
                flushParagraph()
                flushList()
                blocks.append("<h\(heading.level)>\(MarkdownInlineRenderer.render(heading.text))</h\(heading.level)>")
                index += 1
                continue
            }

            if MarkdownPatterns.isHorizontalRule(trimmed) {
                flushParagraph()
                flushList()
                blocks.append("<hr>")
                index += 1
                continue
            }

            if index + 1 < lines.count, let table = MarkdownPatterns.table(startingAt: index, lines: lines) {
                flushParagraph()
                flushList()
                blocks.append(table.html)
                index = table.nextIndex
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushList()
                var quoteLines: [String] = []

                while index < lines.count {
                    let quoteLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteLine.hasPrefix(">") else { break }
                    quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }

                blocks.append("<blockquote>\(MarkdownBlockParser(markdown: quoteLines.joined(separator: "\n")).render())</blockquote>")
                continue
            }

            if let item = MarkdownPatterns.listItem(in: trimmed) {
                flushParagraph()
                listItems.append(item)
                index += 1
                continue
            }

            flushList()
            paragraph.append(trimmed)
            index += 1
        }

        flushParagraph()
        flushList()
        return blocks.joined(separator: "\n")
    }
}

private struct MarkdownListItem {
    let ordered: Bool
    let text: String
    let checked: Bool?
}

private enum MarkdownPatterns {
    static func heading(in line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes),
              line.dropFirst(hashes).first == " "
        else {
            return nil
        }

        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        return compact.count >= 3 && Set(compact).isSubset(of: ["-"])
            || compact.count >= 3 && Set(compact).isSubset(of: ["*"])
            || compact.count >= 3 && Set(compact).isSubset(of: ["_"])
    }

    static func listItem(in line: String) -> MarkdownListItem? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            let item = taskListItem(from: String(line.dropFirst(2)))
            return MarkdownListItem(ordered: false, text: item.text, checked: item.checked)
        }

        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let prefix = line[..<dotIndex]
        let textStart = line.index(after: dotIndex)
        guard !prefix.isEmpty,
              prefix.allSatisfy(\.isNumber),
              textStart < line.endIndex,
              line[textStart] == " "
        else {
            return nil
        }

        let item = taskListItem(from: String(line[line.index(after: textStart)...]))
        return MarkdownListItem(ordered: true, text: item.text, checked: item.checked)
    }

    private static func taskListItem(from text: String) -> (text: String, checked: Bool?) {
        guard text.count >= 4 else { return (text, nil) }
        let prefix = text.prefix(4).lowercased()

        if prefix == "[ ] " {
            return (String(text.dropFirst(4)), false)
        }

        if prefix == "[x] " {
            return (String(text.dropFirst(4)), true)
        }

        return (text, nil)
    }

    static func table(startingAt index: Int, lines: [String]) -> (html: String, nextIndex: Int)? {
        let header = lines[index].trimmingCharacters(in: .whitespaces)
        let separator = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard header.contains("|"), isTableSeparator(separator) else { return nil }

        var rows: [[String]] = [splitTableRow(header)]
        var nextIndex = index + 2

        while nextIndex < lines.count {
            let row = lines[nextIndex].trimmingCharacters(in: .whitespaces)
            guard row.contains("|"), !row.isEmpty else { break }
            rows.append(splitTableRow(row))
            nextIndex += 1
        }

        guard let headerRow = rows.first else { return nil }
        let bodyRows = rows.dropFirst()
        let columnCount = headerRow.count
        let headHTML = headerRow
            .map { "<th>\(MarkdownInlineRenderer.render($0))</th>" }
            .joined()
        let bodyHTML = bodyRows.map { row in
            let cells = (0..<columnCount).map { columnIndex in
                let value = columnIndex < row.count ? row[columnIndex] : ""
                return "<td>\(MarkdownInlineRenderer.render(value))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        return ("<table><thead><tr>\(headHTML)</tr></thead><tbody>\(bodyHTML)</tbody></table>", nextIndex)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = splitTableRow(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.replacingOccurrences(of: " ", with: "")
            guard compact.count >= 3 else { return false }
            return compact.allSatisfy { character in
                character == "-" || character == ":"
            }
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

private enum MarkdownInlineRenderer {
    static func render(_ text: String) -> String {
        var output = HTML.escape(text)

        output = replace(pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#, in: output) { match in
            guard match.count == 3 else { return match.first ?? "" }
            return "<img src=\"\(HTML.escapeAttribute(match[2]))\" alt=\"\(HTML.escapeAttribute(match[1]))\">"
        }

        output = replace(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, in: output) { match in
            guard match.count == 3 else { return match.first ?? "" }
            return "<a href=\"\(HTML.escapeAttribute(match[2]))\">\(match[1])</a>"
        }

        output = replace(pattern: #"`([^`]+)`"#, in: output) { match in
            guard match.count == 2 else { return match.first ?? "" }
            return "<code>\(match[1])</code>"
        }

        output = replace(pattern: #"\*\*([^*]+)\*\*|__([^_]+)__"#, in: output) { match in
            let value = match.count > 2 && !match[2].isEmpty ? match[2] : match[safe: 1] ?? ""
            return "<strong>\(value)</strong>"
        }

        output = replace(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)|_([^_]+)_"#, in: output) { match in
            let value = match.count > 2 && !match[2].isEmpty ? match[2] : match[safe: 1] ?? ""
            return "<em>\(value)</em>"
        }

        output = replace(pattern: #"~~([^~]+)~~"#, in: output) { match in
            guard match.count == 2 else { return match.first ?? "" }
            return "<del>\(match[1])</del>"
        }

        return output
    }

    private static func replace(
        pattern: String,
        in text: String,
        replacement: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var output = text

        for match in matches {
            let captures = (0..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return "" }
                return nsText.substring(with: range)
            }
            if let range = Range(match.range, in: output) {
                output.replaceSubrange(range, with: replacement(captures))
            }
        }

        return output
    }
}

private enum HTML {
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ text: String) -> String {
        escape(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
