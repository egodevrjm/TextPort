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

    @Published var customSyntaxDefinitions: [CustomSyntaxDefinition] {
        didSet { save() }
    }

    @Published var enableSharingTools: Bool {
        didSet {
            if !enableSharingTools {
                enableGitHubTools = false
                enablePublishingActions = false
            }
            save()
        }
    }

    @Published var enableGitHubTools: Bool {
        didSet {
            if !enableGitHubTools {
                enablePublishingActions = false
            }
            save()
        }
    }

    @Published var enablePublishingActions: Bool {
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
            customSyntaxDefinitions = stored.customSyntaxDefinitions ?? []
            enableSharingTools = stored.enableSharingTools ?? false
            enableGitHubTools = stored.enableGitHubTools ?? false
            enablePublishingActions = stored.enablePublishingActions ?? false
        } else {
            fontSize = 14
            showLineNumbers = false
            wordWrap = true
            renderPreview = false
            restoreSession = true
            reuseBlankTabWhenOpening = true
            defaultEncoding = .utf8
            defaultLineEnding = .lf
            customSyntaxDefinitions = []
            enableSharingTools = false
            enableGitHubTools = false
            enablePublishingActions = false
        }
    }

    func customSyntaxDefinition(id: UUID?) -> CustomSyntaxDefinition? {
        guard let id else { return nil }
        return customSyntaxDefinitions.first { $0.id == id }
    }

    func matchingCustomSyntax(fileName: String, text: String) -> CustomSyntaxDefinition? {
        customSyntaxDefinitions.first { $0.matches(fileName: fileName, text: text) }
    }

    func upsertCustomSyntax(_ definition: CustomSyntaxDefinition) {
        let normalizedDefinition = CustomSyntaxDefinition(
            id: definition.id,
            name: definition.displayName,
            fileExtensions: definition.fileExtensions,
            keywords: definition.keywords,
            singleLineComment: definition.singleLineComment,
            blockCommentStart: definition.blockCommentStart,
            blockCommentEnd: definition.blockCommentEnd,
            stringDelimiters: definition.stringDelimiters,
            caseSensitive: definition.caseSensitive
        )

        if let index = customSyntaxDefinitions.firstIndex(where: { $0.id == definition.id }) {
            customSyntaxDefinitions[index] = normalizedDefinition
        } else {
            customSyntaxDefinitions.append(normalizedDefinition)
        }
    }

    func removeCustomSyntax(id: UUID) {
        customSyntaxDefinitions.removeAll { $0.id == id }
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
            defaultLineEnding: defaultLineEnding,
            customSyntaxDefinitions: customSyntaxDefinitions,
            enableSharingTools: enableSharingTools,
            enableGitHubTools: enableGitHubTools,
            enablePublishingActions: enablePublishingActions
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
    var customSyntaxDefinitions: [CustomSyntaxDefinition]?
    var enableSharingTools: Bool?
    var enableGitHubTools: Bool?
    var enablePublishingActions: Bool?
}
