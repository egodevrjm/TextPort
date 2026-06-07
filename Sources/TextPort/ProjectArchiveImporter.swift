import Foundation
import UniformTypeIdentifiers

enum ProjectArchiveImporter {
    static let zipContentType = UTType(filenameExtension: "zip") ?? .archive

    static func isZipArchive(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "zip"
    }

    static func extractProject(from archiveURL: URL) throws -> URL {
        let destinationURL = try makeDestinationURL(for: archiveURL)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        do {
            try extract(archiveURL: archiveURL, to: destinationURL)
            return projectRoot(in: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    private static func extract(archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ProjectArchiveImportError.extractFailed
        }
    }

    private static func projectRoot(in extractedURL: URL) -> URL {
        let visibleContents = ((try? FileManager.default.contentsOfDirectory(
            at: extractedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
        .filter { url in
            let name = url.lastPathComponent
            return name != "__MACOSX" && name != ".DS_Store"
        }

        if visibleContents.count == 1,
           let onlyChild = visibleContents.first,
           (try? onlyChild.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return onlyChild
        }

        return extractedURL
    }

    private static func makeDestinationURL(for archiveURL: URL) throws -> URL {
        let importedProjectsURL = try importedProjectsDirectory()
        let baseName = sanitizedProjectName(archiveURL.deletingPathExtension().lastPathComponent)
        var candidate = importedProjectsURL.appendingPathComponent(baseName, isDirectory: true)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = importedProjectsURL.appendingPathComponent("\(baseName) \(index)", isDirectory: true)
            index += 1
        }

        return candidate
    }

    private static func importedProjectsDirectory() throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directoryURL = baseURL
            .appendingPathComponent("TextPort", isDirectory: true)
            .appendingPathComponent("Imported Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func sanitizedProjectName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-"))
        let sanitized = String(name.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        })
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "Imported Project" : sanitized
    }
}

enum ProjectArchiveImportError: LocalizedError {
    case extractFailed

    var errorDescription: String? {
        switch self {
        case .extractFailed:
            return "TextPort could not extract this zip archive."
        }
    }
}
