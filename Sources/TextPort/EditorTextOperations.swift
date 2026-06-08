import Foundation

struct EditorTextOperationResult: Equatable {
    let text: String
    let selectionRange: NSRange
}

enum EditorTextOperations {
    static func duplicateLines(text: String, selection: NSRange, preferredLineEnding: TextLineEnding) -> EditorTextOperationResult {
        var document = LineDocument(text: text)
        let selectedRange = document.selectedLineRange(for: selection)
        let copiedContents = Array(document.contents[selectedRange])
        let copiedEndings = Array(document.endings[selectedRange])

        if document.endings[selectedRange.upperBound - 1].isEmpty {
            document.endings[selectedRange.upperBound - 1] = defaultLineEnding(for: preferredLineEnding)
        }

        document.contents.insert(contentsOf: copiedContents, at: selectedRange.upperBound)
        document.endings.insert(contentsOf: copiedEndings, at: selectedRange.upperBound)

        let newSelection = document.contentRange(for: selectedRange.upperBound..<(selectedRange.upperBound + copiedContents.count))
        return EditorTextOperationResult(text: document.text, selectionRange: newSelection)
    }

    static func deleteLines(text: String, selection: NSRange) -> EditorTextOperationResult? {
        var document = LineDocument(text: text)
        let selectedRange = document.selectedLineRange(for: selection)
        guard !document.contents.isEmpty else { return nil }

        let deletingAtEnd = selectedRange.upperBound == document.contents.count
        document.contents.removeSubrange(selectedRange)
        document.endings.removeSubrange(selectedRange)

        if document.contents.isEmpty {
            return EditorTextOperationResult(text: "", selectionRange: NSRange(location: 0, length: 0))
        }

        if deletingAtEnd {
            document.endings[document.endings.count - 1] = ""
        }

        let lineIndex = min(selectedRange.lowerBound, document.contents.count - 1)
        let location = document.lineStartOffset(at: lineIndex)
        return EditorTextOperationResult(text: document.text, selectionRange: NSRange(location: location, length: 0))
    }

    static func moveLinesUp(text: String, selection: NSRange) -> EditorTextOperationResult? {
        var document = LineDocument(text: text)
        let selectedRange = document.selectedLineRange(for: selection)
        guard selectedRange.lowerBound > 0 else { return nil }

        let movedContents = Array(document.contents[selectedRange])
        document.contents.removeSubrange(selectedRange)
        let insertionIndex = selectedRange.lowerBound - 1
        document.contents.insert(contentsOf: movedContents, at: insertionIndex)

        let newSelection = document.contentRange(for: insertionIndex..<(insertionIndex + movedContents.count))
        return EditorTextOperationResult(text: document.text, selectionRange: newSelection)
    }

    static func moveLinesDown(text: String, selection: NSRange) -> EditorTextOperationResult? {
        var document = LineDocument(text: text)
        let selectedRange = document.selectedLineRange(for: selection)
        guard selectedRange.upperBound < document.contents.count else { return nil }

        let movedContents = Array(document.contents[selectedRange])
        document.contents.removeSubrange(selectedRange)
        let insertionIndex = selectedRange.lowerBound + 1
        document.contents.insert(contentsOf: movedContents, at: insertionIndex)

        let newSelection = document.contentRange(for: insertionIndex..<(insertionIndex + movedContents.count))
        return EditorTextOperationResult(text: document.text, selectionRange: newSelection)
    }

    static func joinLines(text: String, selection: NSRange) -> EditorTextOperationResult? {
        var document = LineDocument(text: text)
        var selectedRange = document.selectedLineRange(for: selection)

        if selectedRange.count == 1 {
            guard selectedRange.upperBound < document.contents.count else { return nil }
            selectedRange = selectedRange.lowerBound..<(selectedRange.upperBound + 1)
        }

        let joinedContent = document.contents[selectedRange]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let finalEnding = document.endings[selectedRange.upperBound - 1]

        document.contents.replaceSubrange(selectedRange, with: [joinedContent])
        document.endings.replaceSubrange(selectedRange, with: [finalEnding])

        let selectionRange = NSRange(
            location: document.lineStartOffset(at: selectedRange.lowerBound),
            length: (joinedContent as NSString).length
        )
        return EditorTextOperationResult(text: document.text, selectionRange: selectionRange)
    }

    static func toggleLineComment(text: String, selection: NSRange, token: String) -> EditorTextOperationResult {
        var document = LineDocument(text: text)
        let selectedRange = document.selectedLineRange(for: selection)
        let activeIndexes = selectedRange.filter { !document.contents[$0].trimmingCharacters(in: .whitespaces).isEmpty }
        let shouldUncomment = !activeIndexes.isEmpty && activeIndexes.allSatisfy { index in
            lineHasComment(document.contents[index], token: token)
        }

        for index in activeIndexes {
            if shouldUncomment {
                document.contents[index] = uncommentLine(document.contents[index], token: token)
            } else {
                document.contents[index] = commentLine(document.contents[index], token: token)
            }
        }

        let newSelection = document.contentRange(for: selectedRange)
        return EditorTextOperationResult(text: document.text, selectionRange: newSelection)
    }

    static func selectedLineContentsRange(text: String, selection: NSRange) -> NSRange {
        let document = LineDocument(text: text)
        return document.contentRange(for: document.selectedLineRange(for: selection))
    }

    static func lineStartRange(text: String, lineNumber: Int) -> NSRange {
        let document = LineDocument(text: text)
        let requestedIndex = max(0, lineNumber - 1)
        let lineIndex = min(requestedIndex, max(document.contents.count - 1, 0))
        return NSRange(location: document.lineStartOffset(at: lineIndex), length: 0)
    }

    private static func defaultLineEnding(for preferredLineEnding: TextLineEnding) -> String {
        preferredLineEnding.sequence ?? "\n"
    }

    private static func lineHasComment(_ line: String, token: String) -> Bool {
        let trimmed = line.drop { $0 == " " || $0 == "\t" }
        return trimmed.hasPrefix(token)
    }

    private static func commentLine(_ line: String, token: String) -> String {
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        let rest = line.dropFirst(indentation.count)
        return "\(indentation)\(token) \(rest)"
    }

    private static func uncommentLine(_ line: String, token: String) -> String {
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        var rest = line.dropFirst(indentation.count)

        if rest.hasPrefix(token) {
            rest = rest.dropFirst(token.count)
            if rest.first == " " {
                rest = rest.dropFirst()
            }
        }

        return "\(indentation)\(rest)"
    }
}

private struct LineDocument {
    var contents: [String]
    var endings: [String]

    init(text: String) {
        let parsedLines = Self.parse(text)
        contents = parsedLines.map(\.content)
        endings = parsedLines.map(\.ending)
    }

    var text: String {
        zip(contents, endings)
            .map { $0 + $1 }
            .joined()
    }

    func selectedLineRange(for selection: NSRange) -> Range<Int> {
        guard !contents.isEmpty else { return 0..<1 }

        let totalLength = textUTF16Length
        let startLocation = clamp(selection.location, lower: 0, upper: totalLength)
        let endLocation: Int

        if selection.length > 0 {
            endLocation = clamp(NSMaxRange(selection) - 1, lower: startLocation, upper: max(totalLength - 1, 0))
        } else {
            endLocation = startLocation
        }

        let startIndex = lineIndex(containing: startLocation)
        let endIndex = lineIndex(containing: endLocation)
        return startIndex..<(endIndex + 1)
    }

    func contentRange(for lineRange: Range<Int>) -> NSRange {
        let start = lineStartOffset(at: lineRange.lowerBound)
        let end = lineContentEndOffset(at: lineRange.upperBound - 1)
        return NSRange(location: start, length: max(0, end - start))
    }

    func lineStartOffset(at index: Int) -> Int {
        guard index > 0 else { return 0 }
        return (0..<min(index, contents.count)).reduce(0) { partialResult, currentIndex in
            partialResult + utf16Length(contents[currentIndex]) + utf16Length(endings[currentIndex])
        }
    }

    private func lineContentEndOffset(at index: Int) -> Int {
        lineStartOffset(at: index) + utf16Length(contents[index])
    }

    private var textUTF16Length: Int {
        contents.indices.reduce(0) { partialResult, index in
            partialResult + utf16Length(contents[index]) + utf16Length(endings[index])
        }
    }

    private func lineIndex(containing location: Int) -> Int {
        var offset = 0

        for index in contents.indices {
            let length = utf16Length(contents[index]) + utf16Length(endings[index])
            let nextOffset = offset + length

            if length == 0 {
                if location == offset {
                    return index
                }
            } else if location < nextOffset {
                return index
            }

            offset = nextOffset
        }

        return max(contents.count - 1, 0)
    }

    private func utf16Length(_ string: String) -> Int {
        (string as NSString).length
    }

    private static func parse(_ text: String) -> [(content: String, ending: String)] {
        guard !text.isEmpty else { return [(content: "", ending: "")] }

        var lines: [(content: String, ending: String)] = []
        var current = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\r" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    lines.append((content: current, ending: "\r\n"))
                    current = ""
                    index = text.index(after: nextIndex)
                } else {
                    lines.append((content: current, ending: "\r"))
                    current = ""
                    index = nextIndex
                }
            } else if character == "\n" {
                lines.append((content: current, ending: "\n"))
                current = ""
                index = text.index(after: index)
            } else {
                current.append(character)
                index = text.index(after: index)
            }
        }

        lines.append((content: current, ending: ""))
        return lines
    }

    private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
