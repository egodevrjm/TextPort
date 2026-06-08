import SwiftUI

struct CustomSyntaxManagerView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var draft = CustomSyntaxDraft(definition: .starter())

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HSplitView {
                VStack(spacing: 0) {
                    List(selection: $selectedID) {
                        ForEach(preferences.customSyntaxDefinitions) { definition in
                            Text(definition.displayName)
                                .tag(definition.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .frame(minWidth: 210, idealWidth: 230)

                    Divider()

                    HStack {
                        Button {
                            addDefinition()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add Syntax")

                        Button {
                            deleteSelectedDefinition()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .help("Delete Syntax")
                        .disabled(selectedID == nil)

                        Spacer()
                    }
                    .padding(8)
                    .background(.bar)
                }

                Form {
                    Section("Definition") {
                        TextField("Name", text: $draft.name)
                        TextField("Extensions", text: $draft.extensionsText)
                    }

                    Section("Tokens") {
                        TextEditor(text: $draft.keywordsText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 110)

                        Toggle("Case Sensitive Keywords", isOn: $draft.caseSensitive)
                    }

                    Section("Comments") {
                        TextField("Line Comment", text: $draft.singleLineComment)

                        HStack {
                            TextField("Block Start", text: $draft.blockCommentStart)
                            TextField("Block End", text: $draft.blockCommentEnd)
                        }
                    }

                    Section("Strings") {
                        TextField("Delimiters", text: $draft.stringDelimitersText)
                    }
                }
                .formStyle(.grouped)
                .padding(20)
                .frame(minWidth: 520)
            }

            Divider()
            footer
        }
        .frame(minWidth: 780, idealWidth: 860, minHeight: 560, idealHeight: 620)
        .onAppear(perform: loadInitialSelection)
        .onChange(of: selectedID) { _, newValue in
            loadDefinition(id: newValue)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            Text("Custom Syntaxes")
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var footer: some View {
        HStack {
            Button("Apply to Current Tab") {
                saveDraft()
                document.setActiveCustomSyntaxDefinition(draft.id)
            }
            .disabled(!draft.isValid)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                saveDraft()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.isValid)

            Button("Done") {
                if draft.isValid {
                    saveDraft()
                }
                dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func loadInitialSelection() {
        if let selectedID, preferences.customSyntaxDefinition(id: selectedID) != nil {
            loadDefinition(id: selectedID)
            return
        }

        if let first = preferences.customSyntaxDefinitions.first {
            selectedID = first.id
            draft = CustomSyntaxDraft(definition: first)
        } else {
            selectedID = nil
            draft = CustomSyntaxDraft(definition: .starter())
        }
    }

    private func addDefinition() {
        let baseName = "Custom Syntax"
        let existingNames = Set(preferences.customSyntaxDefinitions.map(\.displayName))
        var name = baseName
        var index = 2

        while existingNames.contains(name) {
            name = "\(baseName) \(index)"
            index += 1
        }

        let definition = CustomSyntaxDefinition.starter(named: name)
        selectedID = nil
        draft = CustomSyntaxDraft(definition: definition)
    }

    private func deleteSelectedDefinition() {
        guard let selectedID else { return }
        preferences.removeCustomSyntax(id: selectedID)

        if let first = preferences.customSyntaxDefinitions.first {
            self.selectedID = first.id
            draft = CustomSyntaxDraft(definition: first)
        } else {
            self.selectedID = nil
            draft = CustomSyntaxDraft(definition: .starter())
        }
    }

    private func loadDefinition(id: UUID?) {
        guard let definition = preferences.customSyntaxDefinition(id: id) else { return }
        draft = CustomSyntaxDraft(definition: definition)
    }

    private func saveDraft() {
        guard draft.isValid else { return }
        let definition = draft.definition
        preferences.upsertCustomSyntax(definition)
        selectedID = definition.id
        document.statusText = "Saved \(definition.displayName)"
    }
}

private struct CustomSyntaxDraft: Equatable {
    var id: UUID
    var name: String
    var extensionsText: String
    var keywordsText: String
    var singleLineComment: String
    var blockCommentStart: String
    var blockCommentEnd: String
    var stringDelimitersText: String
    var caseSensitive: Bool

    init(definition: CustomSyntaxDefinition) {
        id = definition.id
        name = definition.displayName
        extensionsText = SyntaxListParser.display(definition.fileExtensions)
        keywordsText = SyntaxListParser.display(definition.keywords)
        singleLineComment = definition.singleLineComment
        blockCommentStart = definition.blockCommentStart
        blockCommentEnd = definition.blockCommentEnd
        stringDelimitersText = SyntaxListParser.display(definition.stringDelimiters)
        caseSensitive = definition.caseSensitive
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var definition: CustomSyntaxDefinition {
        CustomSyntaxDefinition(
            id: id,
            name: name,
            fileExtensions: SyntaxListParser.parse(extensionsText),
            keywords: SyntaxListParser.parse(keywordsText),
            singleLineComment: singleLineComment.trimmingCharacters(in: .whitespacesAndNewlines),
            blockCommentStart: blockCommentStart.trimmingCharacters(in: .whitespacesAndNewlines),
            blockCommentEnd: blockCommentEnd.trimmingCharacters(in: .whitespacesAndNewlines),
            stringDelimiters: SyntaxListParser.parse(stringDelimitersText),
            caseSensitive: caseSensitive
        )
    }
}
