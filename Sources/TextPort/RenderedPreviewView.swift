import SwiftUI
import WebKit

enum RenderedPreviewKind {
    case html
    case markdown

    static func detect(fileName: String, syntaxMode: SyntaxHighlightMode) -> RenderedPreviewKind? {
        switch syntaxMode {
        case .html:
            return .html
        case .markdown:
            return .markdown
        default:
            break
        }

        switch fileName.fileExtension.lowercased() {
        case "html", "htm", "xml":
            return .html
        case "md", "markdown", "mdown":
            return .markdown
        default:
            return nil
        }
    }
}

struct RenderedPreviewView: View {
    let tab: TextDocumentTab
    let kind: RenderedPreviewKind

    var body: some View {
        switch kind {
        case .html:
            HTMLPreviewView(html: tab.text, baseURL: tab.fileURL?.deletingLastPathComponent())
        case .markdown:
            MarkdownPreviewView(markdown: tab.text)
        }
    }
}

private struct MarkdownPreviewView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                markdownText
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var markdownText: Text {
        if let attributedString = try? AttributedString(markdown: markdown) {
            return Text(attributedString)
        }

        return Text(markdown)
    }
}

private struct HTMLPreviewView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
