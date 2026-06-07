import SwiftUI

struct QuickOpenView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var project: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("Open quickly", text: $document.quickOpenQuery)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)

            List(quickOpenItems) { item in
                Button {
                    document.openQuickOpenItem(item)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.body)
                                .lineLimit(1)

                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Text(kindLabel(for: item.kind))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 300)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 560)
        .onAppear {
            searchFocused = true
        }
    }

    private var quickOpenItems: [QuickOpenItem] {
        let projectItems = project.hasProject
            ? project.quickOpenItems(matching: document.quickOpenQuery)
            : []
        return Array((document.filteredQuickOpenItems + projectItems).prefix(80))
    }

    private func kindLabel(for kind: QuickOpenKind) -> String {
        switch kind {
        case .openTab:
            "Tab"
        case .recentFile:
            "Recent"
        case .projectFile:
            "Project"
        }
    }
}
