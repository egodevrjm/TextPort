import Foundation

struct ImportedSpreadsheetSheet {
    let name: String
    let csvText: String
}

enum OfficeImportService {
    static func isSpreadsheet(_ url: URL) -> Bool {
        ["xlsx", "xlsm"].contains(url.pathExtension.lowercased())
    }

    static func isLegacyExcel(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "xls"
    }

    static func isLegacyPowerPoint(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "ppt"
    }

    static func isExtractedTextDocument(_ url: URL) -> Bool {
        ["docx", "pdf", "pptx"].contains(url.pathExtension.lowercased())
    }

    static func extractedDisplayName(for url: URL) -> String {
        let baseName = url.deletingPathExtension().lastPathComponent

        switch url.pathExtension.lowercased() {
        case "docx":
            return "\(baseName) Word Text.txt"
        case "pdf":
            return "\(baseName) PDF Text.txt"
        case "pptx":
            return "\(baseName) PowerPoint Text.txt"
        default:
            return url.lastPathComponent
        }
    }

    static func extractedStatus(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "docx":
            return "Extracted text from \(url.lastPathComponent)"
        case "pdf":
            return "Extracted text from \(url.lastPathComponent)"
        case "pptx":
            return "Extracted slide text from \(url.lastPathComponent)"
        default:
            return "Opened \(url.lastPathComponent)"
        }
    }

    static func loadWordDocument(url: URL) throws -> LoadedTextFile {
        let extractedDirectory = try ZipArchiveExtractor.extract(url: url)
        defer { try? FileManager.default.removeItem(at: extractedDirectory) }

        let documentURL = extractedDirectory.appendingPathComponent("word/document.xml")
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            throw OfficeImportError.missingWordDocument
        }

        let text = ImportedTextCleaner.clean(
            try WordDocumentXMLTextParser.parse(url: documentURL),
            source: .wordDocument
        )
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OfficeImportError.noExtractableText
        }

        return LoadedTextFile(text: text, textEncoding: .utf8, lineEnding: .lf)
    }

    static func loadPresentation(url: URL) throws -> LoadedTextFile {
        let extractedDirectory = try ZipArchiveExtractor.extract(url: url)
        defer { try? FileManager.default.removeItem(at: extractedDirectory) }

        let slidesDirectory = extractedDirectory.appendingPathComponent("ppt/slides", isDirectory: true)
        let slideURLs = ((try? FileManager.default.contentsOfDirectory(at: slidesDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "xml" && $0.lastPathComponent.hasPrefix("slide") }
            .sorted { slideNumber(from: $0) < slideNumber(from: $1) }

        guard !slideURLs.isEmpty else {
            throw OfficeImportError.missingPresentationSlides
        }

        let slideTexts = try slideURLs.enumerated().compactMap { index, slideURL -> String? in
            let text = try OfficeTextXMLParser.parse(url: slideURL)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return "Slide \(index + 1)\n\(text)"
        }

        guard !slideTexts.isEmpty else {
            throw OfficeImportError.noExtractableText
        }

        return LoadedTextFile(
            text: slideTexts.joined(separator: "\n\n"),
            textEncoding: .utf8,
            lineEnding: .lf
        )
    }

    static func loadSpreadsheet(url: URL) throws -> [ImportedSpreadsheetSheet] {
        let extractedDirectory = try ZipArchiveExtractor.extract(url: url)
        defer { try? FileManager.default.removeItem(at: extractedDirectory) }

        let xlDirectory = extractedDirectory.appendingPathComponent("xl", isDirectory: true)
        let workbookURL = xlDirectory.appendingPathComponent("workbook.xml")
        let relationshipsURL = xlDirectory.appendingPathComponent("_rels/workbook.xml.rels")

        guard FileManager.default.fileExists(atPath: workbookURL.path) else {
            throw OfficeImportError.missingWorkbook
        }

        let workbookSheets = try WorkbookSheetsParser.parse(url: workbookURL)
        guard !workbookSheets.isEmpty else {
            throw OfficeImportError.emptyWorkbook
        }

        let relationships = try WorkbookRelationshipsParser.parse(url: relationshipsURL)
        let sharedStringsURL = xlDirectory.appendingPathComponent("sharedStrings.xml")
        let sharedStrings = FileManager.default.fileExists(atPath: sharedStringsURL.path)
            ? (try SharedStringsParser.parse(url: sharedStringsURL))
            : []

        let importedSheets = try workbookSheets.compactMap { sheet -> ImportedSpreadsheetSheet? in
            guard let target = relationships[sheet.relationshipID] else { return nil }
            let sheetURL = resolvedRelationshipTarget(target, relativeTo: xlDirectory, extractedDirectory: extractedDirectory)
            guard FileManager.default.fileExists(atPath: sheetURL.path) else { return nil }

            let rows = try WorksheetParser.parse(url: sheetURL, sharedStrings: sharedStrings)
            let csvText = CSVWriter.write(rows: rows)
            return ImportedSpreadsheetSheet(name: sheet.name, csvText: csvText)
        }

        guard !importedSheets.isEmpty else {
            throw OfficeImportError.emptyWorkbook
        }

        return importedSheets
    }

    private static func resolvedRelationshipTarget(
        _ target: String,
        relativeTo xlDirectory: URL,
        extractedDirectory: URL
    ) -> URL {
        if target.hasPrefix("/") {
            return extractedDirectory.appendingPathComponent(String(target.dropFirst()))
        }

        return xlDirectory.appendingPathComponent(target)
    }

    private static func slideNumber(from url: URL) -> Int {
        let fileName = url.deletingPathExtension().lastPathComponent
        let digits = fileName.filter(\.isNumber)
        return Int(digits) ?? Int.max
    }
}

enum OfficeImportError: LocalizedError {
    case archiveExtractionFailed
    case emptyWorkbook
    case legacyExcelUnsupported
    case legacyPowerPointUnsupported
    case missingWorkbook
    case missingPresentationSlides
    case missingWordDocument
    case noExtractableText
    case xmlParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .archiveExtractionFailed:
            "TextPort could not unpack this Office file."
        case .emptyWorkbook:
            "TextPort opened the workbook, but it did not contain any readable sheets."
        case .legacyExcelUnsupported:
            "Legacy .xls files are not supported yet. Save the workbook as .xlsx and open it again."
        case .legacyPowerPointUnsupported:
            "Legacy .ppt files are not supported yet. Save the presentation as .pptx and open it again."
        case .missingWorkbook:
            "TextPort could not find the workbook data in this Excel file."
        case .missingPresentationSlides:
            "TextPort could not find the slide data in this PowerPoint file."
        case .missingWordDocument:
            "TextPort could not find the document text in this Word file."
        case .noExtractableText:
            "TextPort opened the file, but it does not contain extractable text."
        case .xmlParsingFailed(let fileName):
            "TextPort could not read \(fileName)."
        }
    }
}

private enum ZipArchiveExtractor {
    static func extract(url: URL) throws -> URL {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextPort-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", url.path, "-d", destinationURL.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw OfficeImportError.archiveExtractionFailed
        }

        return destinationURL
    }
}

private final class OfficeTextXMLParser: NSObject, XMLParserDelegate {
    private var text = ""
    private var isReadingText = false

    static func parse(url: URL) throws -> String {
        let parserDelegate = OfficeTextXMLParser()
        try XMLParsing.run(url: url, delegate: parserDelegate)
        return parserDelegate.cleanedText
    }

    private var cleanedText: String {
        text
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if matches(elementName, "t") {
            isReadingText = true
        } else if matches(elementName, "tab") {
            text += "\t"
        } else if matches(elementName, "br") {
            text += "\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isReadingText else { return }
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if matches(elementName, "t") {
            isReadingText = false
        } else if matches(elementName, "p") {
            text += "\n"
        } else if matches(elementName, "tc") {
            text += "\t"
        }
    }
}

private enum WordDocumentXMLTextParser {
    static func parse(url: URL) throws -> String {
        try OfficeTextXMLParser.parse(url: url)
    }
}

private struct WorkbookSheetReference {
    let name: String
    let relationshipID: String
}

private final class WorkbookSheetsParser: NSObject, XMLParserDelegate {
    private var sheets: [WorkbookSheetReference] = []

    static func parse(url: URL) throws -> [WorkbookSheetReference] {
        let parserDelegate = WorkbookSheetsParser()
        try XMLParsing.run(url: url, delegate: parserDelegate)
        return parserDelegate.sheets
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard matches(elementName, "sheet"),
              let name = attributeDict["name"],
              let relationshipID = attributeDict["r:id"] ?? attributeDict["id"]
        else {
            return
        }

        sheets.append(WorkbookSheetReference(name: name, relationshipID: relationshipID))
    }
}

private final class WorkbookRelationshipsParser: NSObject, XMLParserDelegate {
    private var relationships: [String: String] = [:]

    static func parse(url: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let parserDelegate = WorkbookRelationshipsParser()
        try XMLParsing.run(url: url, delegate: parserDelegate)
        return parserDelegate.relationships
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard matches(elementName, "Relationship"),
              let id = attributeDict["Id"],
              let target = attributeDict["Target"]
        else {
            return
        }

        relationships[id] = target
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentString = ""
    private var isInsideStringItem = false
    private var isReadingText = false

    static func parse(url: URL) throws -> [String] {
        let parserDelegate = SharedStringsParser()
        try XMLParsing.run(url: url, delegate: parserDelegate)
        return parserDelegate.strings
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if matches(elementName, "si") {
            isInsideStringItem = true
            currentString = ""
        } else if matches(elementName, "t"), isInsideStringItem {
            isReadingText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isReadingText else { return }
        currentString += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if matches(elementName, "t") {
            isReadingText = false
        } else if matches(elementName, "si") {
            strings.append(currentString)
            currentString = ""
            isInsideStringItem = false
        }
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentCellReference = ""
    private var currentCellType: String?
    private var currentValue = ""
    private var inlineString = ""
    private var isInsideValue = false
    private var isInsideInlineString = false
    private var isReadingInlineText = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    static func parse(url: URL, sharedStrings: [String]) throws -> [[String]] {
        let parserDelegate = WorksheetParser(sharedStrings: sharedStrings)
        try XMLParsing.run(url: url, delegate: parserDelegate)
        return parserDelegate.rows
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if matches(elementName, "row") {
            currentRow = []
        } else if matches(elementName, "c") {
            currentCellReference = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"]
            currentValue = ""
            inlineString = ""
        } else if matches(elementName, "v") {
            isInsideValue = true
        } else if matches(elementName, "is") {
            isInsideInlineString = true
        } else if matches(elementName, "t"), isInsideInlineString {
            isReadingInlineText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideValue {
            currentValue += string
        } else if isReadingInlineText {
            inlineString += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if matches(elementName, "v") {
            isInsideValue = false
        } else if matches(elementName, "t"), isInsideInlineString {
            isReadingInlineText = false
        } else if matches(elementName, "is") {
            isInsideInlineString = false
        } else if matches(elementName, "c") {
            appendCurrentCell()
        } else if matches(elementName, "row") {
            trimTrailingEmptyCells()
            rows.append(currentRow)
            currentRow = []
        }
    }

    private func appendCurrentCell() {
        let columnIndex = Self.columnIndex(from: currentCellReference) ?? currentRow.count
        while currentRow.count < columnIndex {
            currentRow.append("")
        }

        currentRow.append(resolvedCurrentValue())
    }

    private func resolvedCurrentValue() -> String {
        switch currentCellType {
        case "s":
            guard let index = Int(currentValue.trimmingCharacters(in: .whitespacesAndNewlines)),
                  sharedStrings.indices.contains(index)
            else {
                return ""
            }
            return sharedStrings[index]
        case "inlineStr":
            return inlineString
        case "b":
            return currentValue.trimmingCharacters(in: .whitespacesAndNewlines) == "1" ? "TRUE" : "FALSE"
        default:
            return currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func trimTrailingEmptyCells() {
        while currentRow.last == "" {
            currentRow.removeLast()
        }
    }

    private static func columnIndex(from cellReference: String) -> Int? {
        let letters = cellReference.prefix { $0.isLetter }
        guard !letters.isEmpty else { return nil }

        return letters.reduce(0) { result, character in
            guard let scalar = character.unicodeScalars.first else { return result }
            let value = Int(scalar.value) - Int(UnicodeScalar("A").value) + 1
            return (result * 26) + value
        } - 1
    }
}

private enum CSVWriter {
    static func write(rows: [[String]]) -> String {
        rows
            .map { row in row.map(escape).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private enum XMLParsing {
    static func run(url: URL, delegate: XMLParserDelegate) throws {
        guard let parser = XMLParser(contentsOf: url) else {
            throw OfficeImportError.xmlParsingFailed(url.lastPathComponent)
        }

        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? OfficeImportError.xmlParsingFailed(url.lastPathComponent)
        }
    }
}

private func matches(_ elementName: String, _ localName: String) -> Bool {
    elementName == localName || elementName.hasSuffix(":\(localName)")
}
