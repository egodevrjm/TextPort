import Foundation

enum ImportedTextCleaner {
    enum Source {
        case pdf
        case wordDocument
    }

    static func clean(_ text: String, source: Source) -> String {
        let normalizedText = normalize(text)
        let rawLines = normalizedText.components(separatedBy: "\n")
        let cleanedLines = removeImportNoise(from: rawLines, source: source)
        let repairedText = repairHyphenatedLineBreaks(in: cleanedLines.joined(separator: "\n"))

        switch source {
        case .pdf:
            return finalPolish(rebuildPDFParagraphs(from: repairedText))
        case .wordDocument:
            return finalPolish(repairedText)
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{000C}", with: "\n\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
    }

    private static func removeImportNoise(from rawLines: [String], source: Source) -> [String] {
        let lines = rawLines.map(normalizedLine)
        let repeatedNoiseKeys = repeatedHeaderFooterKeys(in: lines)
        let standalonePageNumbers = source == .pdf ? inferredStandalonePageNumbers(in: lines) : []
        let filteredLines = lines.filter { line in
            guard !line.isEmpty else { return true }

            if isExplicitPageMarker(line) {
                return false
            }

            if let number = standaloneNumber(from: line), standalonePageNumbers.contains(number) {
                return false
            }

            if repeatedNoiseKeys.contains(noiseKey(for: line)) {
                return false
            }

            return true
        }

        return collapseBlankLines(filteredLines)
    }

    private static func normalizedLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func repeatedHeaderFooterKeys(in lines: [String]) -> Set<String> {
        var counts: [String: Int] = [:]
        var examples: [String: String] = [:]

        for line in lines where !line.isEmpty {
            let key = noiseKey(for: line)
            counts[key, default: 0] += 1
            examples[key] = line
        }

        return Set(counts.compactMap { key, count in
            guard count >= 3,
                  let example = examples[key],
                  isRepeatedHeaderFooterCandidate(example)
            else {
                return nil
            }

            return key
        })
    }

    private static func noiseKey(for line: String) -> String {
        line
            .lowercased()
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isRepeatedHeaderFooterCandidate(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty,
              trimmedLine.count <= 160,
              !isListLine(trimmedLine)
        else {
            return false
        }

        return wordCount(in: trimmedLine) <= 22
    }

    private static func isExplicitPageMarker(_ line: String) -> Bool {
        matches(line, #"^page\s+\d+(\s+of\s+\d+)?$"#)
            || matches(line, #"^\d+\s*(/|of)\s*\d+$"#)
            || matches(line, #"^\p{Pd}\s*\d+\s*\p{Pd}$"#)
    }

    private static func inferredStandalonePageNumbers(in lines: [String]) -> Set<Int> {
        let values = lines.compactMap(standaloneNumber).filter { $0 > 0 && $0 <= 500 }
        guard values.count >= 3 else { return [] }

        let uniqueValues = Array(Set(values)).sorted()
        let adjacentPairs = zip(uniqueValues, uniqueValues.dropFirst()).filter { previous, next in
            next == previous + 1
        }

        if adjacentPairs.count >= max(2, uniqueValues.count - 2) {
            return Set(uniqueValues)
        }

        return []
    }

    private static func standaloneNumber(from line: String) -> Int? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(trimmedLine, #"^\d{1,4}$"#) else { return nil }
        return Int(trimmedLine)
    }

    private static func repairHyphenatedLineBreaks(in text: String) -> String {
        text.replacingOccurrences(
            of: #"([A-Za-z])-\n([a-z])"#,
            with: "$1$2",
            options: .regularExpression
        )
    }

    private static func rebuildPDFParagraphs(from text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var blocks: [String] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(paragraphLines.joined(separator: " "))
            paragraphLines.removeAll()
        }

        for rawLine in lines {
            let line = normalizedLine(rawLine)

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if isListLine(line) || isLikelyHeading(line) {
                flushParagraph()
                blocks.append(line)
                continue
            }

            if let previousLine = paragraphLines.last,
               !shouldJoinPDFLine(previousLine, with: line) {
                flushParagraph()
            }

            paragraphLines.append(line)
        }

        flushParagraph()
        return blocks.joined(separator: "\n\n")
    }

    private static func shouldJoinPDFLine(_ previousLine: String, with nextLine: String) -> Bool {
        if isListLine(previousLine) || isListLine(nextLine) {
            return false
        }

        if isLikelyHeading(previousLine) || isLikelyHeading(nextLine) {
            return false
        }

        if endsWithHardPunctuation(previousLine), startsWithUppercaseLetter(nextLine) {
            return false
        }

        return true
    }

    private static func isLikelyHeading(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = wordCount(in: trimmedLine)

        guard words > 0,
              words <= 10,
              trimmedLine.count <= 90,
              !endsWithHardPunctuation(trimmedLine)
        else {
            return false
        }

        if matches(trimmedLine, #"^\d+(\.\d+)*\.?\s+\S+"#) {
            return true
        }

        if trimmedLine == trimmedLine.uppercased(),
           trimmedLine.rangeOfCharacter(from: .letters) != nil {
            return true
        }

        return false
    }

    private static func isListLine(_ line: String) -> Bool {
        matches(line, #"^[-*+]\s+\S+"#)
            || matches(line, #"^\d+[\.)]\s+\S+"#)
            || matches(line, #"^[A-Za-z][\.)]\s+\S+"#)
            || matches(line, #"^#{1,6}\s+\S+"#)
    }

    private static func collapseBlankLines(_ lines: [String]) -> [String] {
        var collapsedLines: [String] = []
        var previousWasBlank = true

        for line in lines {
            if line.isEmpty {
                if !previousWasBlank {
                    collapsedLines.append("")
                }
                previousWasBlank = true
            } else {
                collapsedLines.append(line)
                previousWasBlank = false
            }
        }

        while collapsedLines.last == "" {
            collapsedLines.removeLast()
        }

        return collapsedLines
    }

    private static func finalPolish(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #" +([,.;:!?])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func startsWithUppercaseLetter(_ line: String) -> Bool {
        guard let firstLetter = line.first(where: { $0.isLetter }) else { return false }
        let letter = String(firstLetter)
        return letter == letter.uppercased() && letter != letter.lowercased()
    }

    private static func endsWithHardPunctuation(_ line: String) -> Bool {
        guard let lastCharacter = line.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }

        return ".?!:".contains(lastCharacter)
    }

    private static func wordCount(in line: String) -> Int {
        line.split { !$0.isLetter && !$0.isNumber }.count
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
