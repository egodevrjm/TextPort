import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @Published var fontSize: Double {
        didSet { save() }
    }

    @Published var showLineNumbers: Bool {
        didSet { save() }
    }

    @Published var wordWrap: Bool {
        didSet { save() }
    }

    @Published var renderPreview: Bool {
        didSet { save() }
    }

    @Published var restoreSession: Bool {
        didSet { save() }
    }

    @Published var reuseBlankTabWhenOpening: Bool {
        didSet { save() }
    }

    @Published var defaultEncoding: TextEncoding {
        didSet { save() }
    }

    @Published var defaultLineEnding: TextLineEnding {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let storageKey = "TextPortPreferences"

    private init() {
        if
            let data = defaults.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data)
        {
            fontSize = stored.fontSize
            showLineNumbers = stored.showLineNumbers
            wordWrap = stored.wordWrap
            renderPreview = stored.renderPreview ?? false
            restoreSession = stored.restoreSession
            reuseBlankTabWhenOpening = stored.reuseBlankTabWhenOpening
            defaultEncoding = stored.defaultEncoding
            defaultLineEnding = stored.defaultLineEnding
        } else {
            fontSize = 14
            showLineNumbers = false
            wordWrap = true
            renderPreview = false
            restoreSession = true
            reuseBlankTabWhenOpening = true
            defaultEncoding = .utf8
            defaultLineEnding = .lf
        }
    }

    private func save() {
        let stored = StoredPreferences(
            fontSize: fontSize,
            showLineNumbers: showLineNumbers,
            wordWrap: wordWrap,
            renderPreview: renderPreview,
            restoreSession: restoreSession,
            reuseBlankTabWhenOpening: reuseBlankTabWhenOpening,
            defaultEncoding: defaultEncoding,
            defaultLineEnding: defaultLineEnding
        )

        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private struct StoredPreferences: Codable {
    var fontSize: Double
    var showLineNumbers: Bool
    var wordWrap: Bool
    var renderPreview: Bool?
    var restoreSession: Bool
    var reuseBlankTabWhenOpening: Bool
    var defaultEncoding: TextEncoding
    var defaultLineEnding: TextLineEnding
}
