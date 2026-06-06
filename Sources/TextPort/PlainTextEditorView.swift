import AppKit
import SwiftUI

@MainActor
struct PlainTextEditorView: NSViewRepresentable {
    var tabID: UUID
    @Binding var text: String
    var fontSize: Double
    var showLineNumbers: Bool
    var wordWrap: Bool
    var syntaxMode: SyntaxHighlightMode
    var selectionChanged: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectionChanged: selectionChanged)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView()
        textView.string = text
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 18, height: 18)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.configure(
            textView: textView,
            scrollView: scrollView,
            fontSize: fontSize,
            showLineNumbers: showLineNumbers,
            wordWrap: wordWrap,
            syntaxMode: syntaxMode
        )

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.visibleRectDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        context.coordinator.text = $text
        context.coordinator.selectionChanged = selectionChanged

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.configure(
            textView: textView,
            scrollView: scrollView,
            fontSize: fontSize,
            showLineNumbers: showLineNumbers,
            wordWrap: wordWrap,
            syntaxMode: syntaxMode
        )
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectionChanged: (String) -> Void
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        private var lineNumberRuler: LineNumberRulerView?
        private var isApplyingSyntax = false
        private var currentSyntaxMode: SyntaxHighlightMode = .plainText

        init(text: Binding<String>, selectionChanged: @escaping (String) -> Void) {
            self.text = text
            self.selectionChanged = selectionChanged
        }

        func configure(
            textView: NSTextView,
            scrollView: NSScrollView,
            fontSize: Double,
            showLineNumbers: Bool,
            wordWrap: Bool,
            syntaxMode: SyntaxHighlightMode
        ) {
            textView.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
            textView.typingAttributes[.font] = textView.font
            configureWrapping(textView: textView, scrollView: scrollView, wordWrap: wordWrap)
            configureLineNumbers(textView: textView, scrollView: scrollView, showLineNumbers: showLineNumbers)
            currentSyntaxMode = syntaxMode
            applySyntax(to: textView, syntaxMode: syntaxMode)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
            lineNumberRuler?.needsDisplay = true
            applySyntax(to: textView, syntaxMode: currentSyntaxMode)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            let range = textView.selectedRange()
            guard range.location != NSNotFound, NSMaxRange(range) <= (textView.string as NSString).length else {
                selectionChanged("")
                return
            }

            selectionChanged((textView.string as NSString).substring(with: range))
        }

        @objc
        func visibleRectDidChange() {
            lineNumberRuler?.needsDisplay = true
        }

        private func configureWrapping(textView: NSTextView, scrollView: NSScrollView, wordWrap: Bool) {
            if wordWrap {
                scrollView.hasHorizontalScroller = false
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                textView.textContainer?.widthTracksTextView = true
                textView.textContainer?.containerSize = NSSize(
                    width: scrollView.contentSize.width,
                    height: .greatestFiniteMagnitude
                )
            } else {
                scrollView.hasHorizontalScroller = true
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
                textView.textContainer?.widthTracksTextView = false
                textView.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
                textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
        }

        private func configureLineNumbers(
            textView: NSTextView,
            scrollView: NSScrollView,
            showLineNumbers: Bool
        ) {
            if showLineNumbers {
                if lineNumberRuler == nil {
                    lineNumberRuler = LineNumberRulerView(textView: textView, scrollView: scrollView)
                }

                scrollView.verticalRulerView = lineNumberRuler
                scrollView.hasVerticalRuler = true
                scrollView.rulersVisible = true
                lineNumberRuler?.needsDisplay = true
            } else {
                scrollView.rulersVisible = false
                scrollView.hasVerticalRuler = false
                scrollView.verticalRulerView = nil
            }
        }

        private func applySyntax(to textView: NSTextView, syntaxMode: SyntaxHighlightMode) {
            guard !isApplyingSyntax else { return }
            isApplyingSyntax = true
            let selectedRanges = textView.selectedRanges
            SyntaxHighlighter.apply(to: textView, mode: syntaxMode)
            textView.selectedRanges = selectedRanges
            isApplyingSyntax = false
        }
    }
}

private final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return
        }

        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let paragraphRanges = paragraphRangesByLocation(in: textView.string as NSString)
        let textInset = textView.textContainerInset

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, glyphRange, _ in
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
            let lineNumber = Self.lineNumber(for: characterIndex, paragraphRanges: paragraphRanges)
            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            let yPosition = usedRect.minY + textInset.height - visibleRect.minY
            let drawPoint = NSPoint(
                x: self.ruleThickness - labelSize.width - 8,
                y: yPosition + 1
            )

            label.draw(at: drawPoint, withAttributes: attributes)
        }
    }

    private func paragraphRangesByLocation(in string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        let fullRange = NSRange(location: 0, length: string.length)
        string.enumerateSubstrings(in: fullRange, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            ranges.append(range)
        }

        if ranges.isEmpty {
            ranges.append(NSRange(location: 0, length: 0))
        }

        return ranges
    }

    private static func lineNumber(for characterIndex: Int, paragraphRanges: [NSRange]) -> Int {
        guard let index = paragraphRanges.firstIndex(where: { NSLocationInRange(characterIndex, $0) || characterIndex == NSMaxRange($0) }) else {
            return paragraphRanges.count
        }

        return index + 1
    }
}
