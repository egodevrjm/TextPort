import SwiftUI
import WebKit

enum RenderedPreviewKind {
    case html
    case markdown
    case json
    case table(DelimitedTextDelimiter)
    case svg

    var label: String {
        switch self {
        case .html:
            return "HTML"
        case .markdown:
            return "Markdown"
        case .json:
            return "JSON"
        case .table(let delimiter):
            return delimiter.label
        case .svg:
            return "SVG"
        }
    }

    static func detect(fileName: String, syntaxMode: SyntaxHighlightMode) -> RenderedPreviewKind? {
        switch fileName.fileExtension.lowercased() {
        case "csv":
            return .table(.comma)
        case "tsv", "tab":
            return .table(.tab)
        case "svg":
            return .svg
        case "json":
            return .json
        case "html", "htm", "xml":
            return .html
        case "md", "markdown", "mdown":
            return .markdown
        default:
            break
        }

        switch syntaxMode {
        case .html:
            return .html
        case .json:
            return .json
        case .markdown:
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
            WebDocumentPreviewView(html: tab.text, baseURL: tab.fileURL?.deletingLastPathComponent())
        case .markdown:
            WebDocumentPreviewView(
                html: MarkdownHTMLRenderer.html(for: tab.text),
                baseURL: tab.fileURL?.deletingLastPathComponent()
            )
        case .json:
            JSONPreviewView(json: tab.text)
        case .table(let delimiter):
            DelimitedTextPreviewView(text: tab.text, delimiter: delimiter)
        case .svg:
            SVGPreviewView(svg: tab.text, baseURL: tab.fileURL?.deletingLastPathComponent())
        }
    }
}

private struct SVGPreviewView: View {
    let svg: String
    let baseURL: URL?

    var body: some View {
        WebDocumentPreviewView(html: SVGPreviewDocument.html(for: svg), baseURL: baseURL)
            .background(Color(nsColor: .textBackgroundColor))
    }
}

private enum SVGPreviewDocument {
    static func html(for svg: String) -> String {
        let encodedSVG = Data(svg.utf8).base64EncodedString()

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root {
            color-scheme: light dark;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            background: transparent;
        }
        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            background: transparent;
        }
        .stage {
            width: calc(100vw - 56px);
            height: calc(100vh - 56px);
            display: grid;
            place-items: center;
        }
        img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
        }
        </style>
        </head>
        <body>
        <main class="stage">
            <img src="data:image/svg+xml;base64,\(encodedSVG)" alt="SVG preview">
        </main>
        </body>
        </html>
        """
    }
}

private struct WebDocumentPreviewView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = webpagePreferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html || context.coordinator.lastBaseURL != baseURL else { return }
        context.coordinator.lastHTML = html
        context.coordinator.lastBaseURL = baseURL
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator {
        var lastHTML: String?
        var lastBaseURL: URL?
    }
}
