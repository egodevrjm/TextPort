import AppKit
import CoreText
import Foundation

@MainActor
enum PrintService {
    static func print(tab: TextDocumentTab, fontSize: Double) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        textView.string = tab.text
        textView.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 36, height: 36)

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.jobDisposition = .spool
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        NSPrintOperation(view: textView, printInfo: printInfo).run()
    }
}

enum PDFTextExporter {
    static func export(tab: TextDocumentTab, fontSize: Double, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let contentBounds = pageBounds.insetBy(dx: 54, dy: 54)
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data) else {
            throw PDFExportError.couldNotCreatePDF
        }

        var mediaBox = pageBounds
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFExportError.couldNotCreatePDF
        }

        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        let attributedText = NSAttributedString(
            string: tab.text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        var currentRange = CFRange(location: 0, length: 0)
        let totalLength = attributedText.length

        repeat {
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            context.translateBy(x: 0, y: pageBounds.height)
            context.scaleBy(x: 1, y: -1)

            let path = CGPath(rect: contentBounds, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            CTFrameDraw(frame, context)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length
            context.endPDFPage()
        } while currentRange.location < totalLength

        context.closePDF()
        try data.write(to: url, options: .atomic)
    }
}

enum PDFExportError: LocalizedError {
    case couldNotCreatePDF

    var errorDescription: String? {
        "TextPort could not create the PDF."
    }
}
