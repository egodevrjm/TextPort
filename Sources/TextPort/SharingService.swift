import AppKit
import Foundation

@MainActor
enum SharingService {
    private static var activePicker: NSSharingServicePicker?

    static func share(items: [Any]) throws {
        guard !items.isEmpty else {
            throw SharingError.noItems
        }

        guard let view = NSApp.keyWindow?.contentView else {
            throw SharingError.noWindow
        }

        let picker = NSSharingServicePicker(items: items)
        let rect = NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        activePicker = picker
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
}

enum ShareItemBuilder {
    static func sourceFile(for tab: TextDocumentTab) throws -> URL {
        if let fileURL = tab.fileURL, !tab.isEdited {
            return fileURL
        }

        let url = try temporaryURL(fileName: tab.fileDisplayName)
        try tab.text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func renderedOutput(for tab: TextDocumentTab, mode: SyntaxHighlightMode, fontSize: Double) throws -> URL {
        if mode == .markdown {
            let url = try temporaryURL(fileName: outputName(for: tab, suffix: "-rendered", extension: "html"))
            try MarkdownHTMLRenderer.html(for: tab.text).write(to: url, atomically: true, encoding: .utf8)
            return url
        }

        if mode == .json {
            switch JSONPreviewParser.parse(tab.text) {
            case .success(let root):
                let url = try temporaryURL(fileName: outputName(for: tab, suffix: "-visual", extension: "html"))
                try JSONVisualHTMLExporter.html(root: root, documentName: tab.fileDisplayName).write(
                    to: url,
                    atomically: true,
                    encoding: .utf8
                )
                return url
            case .failure(let error):
                throw error
            }
        }

        let url = try temporaryURL(fileName: outputName(for: tab, suffix: "", extension: "pdf"))
        try PDFTextExporter.export(tab: tab, fontSize: fontSize, to: url)
        return url
    }

    static func projectBundle(rootURL: URL) throws -> URL {
        let bundleName = "\(sanitize(rootURL.lastPathComponent))-Share.zip"
        let workURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextPortProjectShare-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = workURL.appendingPathComponent(rootURL.lastPathComponent, isDirectory: true)
        let zipURL = try temporaryURL(fileName: bundleName)

        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try copyProjectContents(from: rootURL, to: sourceURL)
        try ZipArchiveWriter.zip(sourceURL: sourceURL, destinationURL: zipURL)
        return zipURL
    }

    private static func copyProjectContents(from sourceRoot: URL, to destinationRoot: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return
        }

        for case let sourceURL as URL in enumerator {
            guard ProjectFileScanner.shouldInclude(url: sourceURL) else {
                if isDirectory(sourceURL) {
                    enumerator.skipDescendants()
                }
                continue
            }

            let relativePath = ProjectFileScanner.relativePath(for: sourceURL, rootURL: sourceRoot)
            let destinationURL = destinationRoot.appendingPathComponent(relativePath)

            if isDirectory(sourceURL) {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
        }
    }

    static func temporaryURL(fileName: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextPortShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(sanitize(fileName))
    }

    private static func outputName(for tab: TextDocumentTab, suffix: String, extension fileExtension: String) -> String {
        let baseName = (tab.fileDisplayName as NSString).deletingPathExtension
        let cleanBaseName = baseName.isEmpty ? "Untitled" : baseName
        return "\(cleanBaseName)\(suffix).\(fileExtension)"
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-"))
        let sanitized = String(name.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        })
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "Untitled.txt" : sanitized
    }
}

enum ZipArchiveWriter {
    static func zip(sourceURL: URL, destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", sourceURL.path, destinationURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SharingError.zipFailed
        }
    }
}

enum SharingError: LocalizedError {
    case noItems
    case noWindow
    case zipFailed

    var errorDescription: String? {
        switch self {
        case .noItems:
            "There is nothing to share."
        case .noWindow:
            "TextPort needs an active window before it can show sharing options."
        case .zipFailed:
            "TextPort could not create the share bundle."
        }
    }
}
