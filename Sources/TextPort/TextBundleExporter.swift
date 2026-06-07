import AppKit
import Foundation
import UniformTypeIdentifiers

enum TextBundleExporter {
    @MainActor
    static func export(tabs: [TextDocumentTab]) throws {
        let panel = NSSavePanel()
        panel.title = "Export Open Tabs Bundle"
        panel.allowedContentTypes = [UTType(filenameExtension: "zip") ?? .zip]
        panel.nameFieldStringValue = "TextPort Export.zip"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        let workURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextPortExport-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = workURL.appendingPathComponent("TextPort Export", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workURL)
        }

        for tab in tabs {
            let fileName = uniqueFileName(for: tab, existingNames: Set((try? FileManager.default.contentsOfDirectory(atPath: sourceURL.path)) ?? []))
            try tab.text.write(to: sourceURL.appendingPathComponent(fileName), atomically: true, encoding: .utf8)

            if tab.fileDisplayName.fileExtension.lowercased().contains("md") {
                let htmlName = (fileName as NSString).deletingPathExtension + ".html"
                try MarkdownHTMLRenderer.html(for: tab.text).write(
                    to: sourceURL.appendingPathComponent(htmlName),
                    atomically: true,
                    encoding: .utf8
                )
            }
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", sourceURL.path, destinationURL.path]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw TextBundleExportError.zipFailed
        }
    }

    private static func uniqueFileName(for tab: TextDocumentTab, existingNames: Set<String>) -> String {
        let sanitized = sanitize(tab.fileDisplayName)
        let baseName = (sanitized as NSString).deletingPathExtension.isEmpty ? "Untitled" : (sanitized as NSString).deletingPathExtension
        let ext = sanitized.fileExtension.isEmpty ? "txt" : sanitized.fileExtension
        var candidate = "\(baseName).\(ext)"
        var index = 2

        while existingNames.contains(candidate) {
            candidate = "\(baseName) \(index).\(ext)"
            index += 1
        }

        return candidate
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-"))
        let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let sanitized = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Untitled.txt" : sanitized
    }
}

enum TextBundleExportError: LocalizedError {
    case zipFailed

    var errorDescription: String? {
        "TextPort could not create the zip archive."
    }
}
