import AppKit
import SwiftUI

@MainActor
struct WindowTitlebarAccessor: NSViewRepresentable {
    @EnvironmentObject private var document: TextDocumentStore

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(document: document)

        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: nsView, document: document)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private weak var window: NSWindow?
        private weak var document: TextDocumentStore?
        private weak var titleField: NSTextField?
        private weak var titlebarView: NSView?
        private var isEditingTitle = false
        private var lastEditRequestID: UUID?

        func installIfNeeded(from view: NSView, document: TextDocumentStore) {
            guard let window = view.window else { return }

            self.window = window
            self.document = document
            configure(window: window, document: document)

            guard titleField == nil else {
                update(document: document)
                return
            }

            guard let titlebarView = window.standardWindowButton(.closeButton)?.superview else {
                return
            }

            let titleField = TitleTextField(frame: .zero)
            titleField.translatesAutoresizingMaskIntoConstraints = false
            titleField.delegate = self
            titleField.target = self
            titleField.action = #selector(commitTitleEdit)
            titleField.stringValue = document.editableFileName
            titleField.alignment = .center
            titleField.font = .systemFont(ofSize: 14, weight: .semibold)
            titleField.isEditable = true
            titleField.isSelectable = true
            titleField.isBordered = false
            titleField.isBezeled = false
            titleField.drawsBackground = false
            titleField.focusRingType = .none
            titleField.lineBreakMode = .byTruncatingMiddle
            titleField.maximumNumberOfLines = 1
            titleField.toolTip = "Click to rename the current file."

            titlebarView.addSubview(titleField)

            NSLayoutConstraint.activate([
                titleField.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
                titleField.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor, constant: 1),
                titleField.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
                titleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
                titleField.heightAnchor.constraint(equalToConstant: 24)
            ])

            self.titleField = titleField
            self.titlebarView = titlebarView
            self.lastEditRequestID = document.titleEditRequestID
        }

        func update(document: TextDocumentStore) {
            self.document = document

            if let window {
                configure(window: window, document: document)
            }

            if let titleField, !isEditingTitle, titleField.stringValue != document.editableFileName {
                titleField.stringValue = document.editableFileName
            }

            if lastEditRequestID != document.titleEditRequestID {
                lastEditRequestID = document.titleEditRequestID
                focusTitleField()
            }
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isEditingTitle = true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let titleField, let document else { return }
            document.updateActiveDisplayName(titleField.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            commitTitleEdit()
        }

        @objc
        private func commitTitleEdit() {
            guard let document else { return }
            document.commitActiveFileNameChange()
            titleField?.stringValue = document.editableFileName
            isEditingTitle = false
        }

        private func focusTitleField() {
            guard let window, let titleField else { return }
            window.makeFirstResponder(titleField)
            titleField.currentEditor()?.selectAll(nil)
        }

        private func configure(window: NSWindow, document: TextDocumentStore) {
            window.title = document.windowTitle
            window.representedURL = document.activeTab.fileURL
            window.isDocumentEdited = document.activeTab.isEdited
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
        }
    }
}

private final class TitleTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        currentEditor()?.selectAll(nil)
    }
}
